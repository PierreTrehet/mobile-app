import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:mobx/mobx.dart';
import 'package:reef_mobile_app/components/modals/reconnect_modal.dart';
import 'package:reef_mobile_app/components/modals/signing_modals.dart';
import 'package:reef_mobile_app/utils/bind_evm.dart';
import '../sign/SignatureContentToggle.dart';
import 'package:reef_mobile_app/components/modal.dart';
import 'package:reef_mobile_app/components/modals/select_account_modal.dart';
import 'package:reef_mobile_app/components/send/custom_stepper.dart';
import 'package:reef_mobile_app/model/ReefAppState.dart';
import 'package:reef_mobile_app/model/account/ReefAccount.dart';
import 'package:reef_mobile_app/model/navigation/navigation_model.dart';
import 'package:reef_mobile_app/model/tokens/TokenWithAmount.dart';
import 'package:reef_mobile_app/utils/constants.dart';
import 'package:reef_mobile_app/utils/elements.dart';
import 'package:reef_mobile_app/utils/styles.dart';
import 'package:reef_mobile_app/utils/functions.dart';
import 'package:reef_mobile_app/flutter_gen/gen_l10n/app_localizations.dart';

enum SendStatus {
  READY,
  NO_EVM_CONNECTED,
  NO_ADDRESS,
  NO_AMT,
  AMT_TOO_HIGH,
  ADDR_NOT_VALID,
  ADDR_NOT_EXIST,
  SIGNING,
  SENDING,
  CANCELED,
  ERROR,
  SENT_TO_NETWORK,
  INCLUDED_IN_BLOCK,
  FINALIZED,
  NOT_FINALIZED,
}

class BindEvm extends StatefulWidget {
  final ReefAccount bindFor;
  final VoidCallback? callback;

  const BindEvm({Key? key, required this.bindFor,this.callback}) : super(key: key);

  @override
  State<BindEvm> createState() => _BindEvmState();
}

class _BindEvmState extends State<BindEvm> {
  bool selectAccount = false;
  dynamic transferBalanceFrom;
  SendStatus statusValue = SendStatus.NO_ADDRESS;
  int currentStep = 0;
  List<ReefAccount> availableTxAccounts = [];
  String address = "";
  String resolvedEvmAddress = "";
  ReefAccount? selectedAccount;
  TextEditingController valueController = TextEditingController();
  StreamController<SendStatus> sendStatusStream = StreamController.broadcast();
  bool boundComplete = false;
  bool sendingFundTransaction = false;
  bool sendingBoundTransaction = false;
  bool recordingChanges = false;
  String? nativeTxStatus;

  final FocusNode _focus = FocusNode();
  final FocusNode _focusSecond = FocusNode();

  var indexerConn = false;
  var providerConn = false;
  var jsConn = false;
  List<StreamSubscription> listeners=[];

  @override
  void initState() {
    listeners.add(ReefAppState.instance.networkCtrl.getProviderConnLogs().listen((event) {
      setState(() {
        this.providerConn = event != null && event.isConnected;
      });
    }));
    listeners.add(ReefAppState.instance.networkCtrl.getIndexerConnected().listen((event) {
      setState(() {
        this.indexerConn = event != null && event==true;
      });
    }));
    ReefAppState.instance.metadataCtrl.getJsConnStream().then((jsStream) {
      listeners.add(jsStream.listen((event) {
        setState(() {
          this.jsConn = event != null && event==true;
        });
      }));
    });
    super.initState();

    if (hasBalanceForBinding(widget.bindFor)) {
      currentStep = 1;
      return;
    }

    availableTxAccounts = getSignersWithEnoughBalance(widget.bindFor);
    if (availableTxAccounts.isNotEmpty) {
      transferBalanceFrom = availableTxAccounts[0];
    }
  }

@override
  void dispose() {
    super.dispose();
    listeners.forEach((element) => element.cancel());
  }
  Future<void> startFunding() async {
    setState(() {
      statusValue = SendStatus.SIGNING;
    });

    setStatusOnSignatureClosed();

    Completer<void> transactionSigned = Completer();

    Stream<dynamic> transferTransactionFeedbackStream =
        await executeTransferTransaction();

    transferTransactionFeedbackStream =
        transferTransactionFeedbackStream.asBroadcastStream();

    transferTransactionFeedbackStream.listen((txResponse) {
      if (!transactionSigned.isCompleted) {
        transactionSigned.complete();
      }
      if (handleExceptionResponse(txResponse)) {
        return;
      }
      if (handleNativeTransferResponse(txResponse)) {
        return;
      }
    });

    await transactionSigned.future;
  }

  void setStatusOnSignatureClosed() {
    when(
        (p0) =>
            ReefAppState.instance.signingCtrl.signatureRequests.list.isNotEmpty,
        () {
      // NEW SIGNATURE DISPLAYED
      when(
          (p0) =>
              ReefAppState.instance.signingCtrl.signatureRequests.list.isEmpty,
          () {
        print('REMOVED SIGN DISPLAY');
        setState(() {
          statusValue = SendStatus.SENDING;
        });
      });
    });
  }

  bool handleExceptionResponse(txResponse) {
    if (txResponse == null || txResponse['success'] != true) {
      setState(() {
        statusValue = txResponse['data'] == '_canceled'
            ? SendStatus.CANCELED
            : SendStatus.ERROR;
      });
      return true;
    }
    return false;
  }

  bool handleNativeTransferResponse(txResponse) {
    print("------------------received feedback------------------");
    print(txResponse['data']['status']);
    if (txResponse['type'] == 'native') {
      if (txResponse['data']['status'] == 'broadcast') {
        setState(() {
          statusValue = SendStatus.SENT_TO_NETWORK;
          nativeTxStatus = AppLocalizations.of(context)!.waiting_to_include_in_block;
        });
      }
      if (txResponse['data']['status'] == 'included-in-block') {
        setState(() {
          statusValue = SendStatus.INCLUDED_IN_BLOCK;
          nativeTxStatus =AppLocalizations.of(context)!.unreversible_finality;
        });
      }
      if (txResponse['data']['status'] == 'finalized') {
        setState(() {
          statusValue = SendStatus.FINALIZED;
          currentStep += 1;
          nativeTxStatus=AppLocalizations.of(context)!.transaction_finalized;
        });
      }
      return true;
    }
    return false;
  }

  Future<Stream<dynamic>> executeTransferTransaction() async {
    TokenWithAmount tokenToTransfer = TokenWithAmount(
        name: 'Reef',
        address: Constants.REEF_TOKEN_ADDRESS,
        iconUrl: '',
        symbol: 'REEF',
        balance: BigInt.zero,
        decimals: 18,
        amount: BigInt.from(MIN_BALANCE * 1e18),
        price: null);

    return ReefAppState.instance.transferCtrl.transferTokensStream(
        selectedAccount?.address ?? transferBalanceFrom.address,
        widget.bindFor.address,
        tokenToTransfer);
  }

  Future<void> transfer() async {
    TokenWithAmount reefToken = TokenWithAmount(
        name: 'Reef',
        address: Constants.REEF_TOKEN_ADDRESS,
        iconUrl: '',
        symbol: 'REEF',
        balance: BigInt.zero,
        decimals: 18,
        amount: BigInt.from(MIN_BALANCE * 1e18),
        price: null);
    await ReefAppState.instance.transferCtrl.transferTokens(
        selectedAccount?.address ?? transferBalanceFrom.address,
        widget.bindFor.address,
        reefToken);
  }

  Widget buildAccount(ReefAccount signer) {
    return ViewBoxContainer(
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black12,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(64),
                      child: signer.iconSVG != null
                          ? SvgPicture.string(
                              signer.iconSVG!,
                              height: 48,
                              width: 48,
                            )
                          : const SizedBox(
                              width: 48,
                              height: 48,
                            ),
                    ),
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signer.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Styles.textColor),
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          Text(
                            signer.address.shorten(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          )),
    );
  }

  Widget buildButton(Future<void> Function() func) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          shadowColor: const Color(0x559d6cff),
          elevation: 5,
          backgroundColor: Styles.primaryAccentColorDark,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () async {
          await func();

        },
        child: Text(
          AppLocalizations.of(context)!.continue_,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget buildSelectAccount(ReefAccount signer) {
    return Flex(
      direction: Axis.horizontal,
      children: [
        SizedBox(
          width: 48,
          child: MaterialButton(
            elevation: 0,
            height: 48,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onPressed: () {
              showSelectAccountModal(
                AppLocalizations.of(context)!.select_address,
                (selectedAddress) async {
                  setState(() {
                    address = selectedAddress.trim();
                    selectedAccount = ReefAppState
                        .instance.model.accounts.accountsList
                        .firstWhere((account) => account.address == address);
                    valueController.text = address;
                  });
                },
                false,
                filterCallback: (signer) => hasBalanceForFunding(signer.data),
              );
            },
            //color: const Color(0xffDFDAED),
            child: const RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Styles.textColor,
                )),
          ),
        ),
        Flexible(
            child: buildAccount(
                selectedAccount ?? (transferBalanceFrom ?? widget.bindFor)))
      ],
    );
  }

  Widget buildSelectAccount2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context)!.select_account,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          )),
      const Gap(8),
      ...availableTxAccounts
          .map<Widget>((account) => Column(children: [
                InkWell(
                    onTap: () {
                      setState(() => {
                            transferBalanceFrom = account,
                            selectAccount = false
                          });
                    },
                    child: (buildAccount(account))),
                const Gap(8),
              ]))
          .toList(),
      const Gap(8),
    ]);
  }


  Widget buildRecordedChanges() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppLocalizations.of(context)!.bind_modal_connected + ':',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Gap(16.0),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.copy,
              size: 12,
              color: Styles.textLightColor,
            ),
            label: Text(
              resolvedEvmAddress.isNotEmpty ? resolvedEvmAddress : '',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Styles.textLightColor),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              backgroundColor: Styles.whiteColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 28),
            ),
            onPressed: () async {
              var copyValue = await ReefAppState.instance.accountCtrl
                  .toReefEVMAddressWithNotificationString(resolvedEvmAddress);
              Clipboard.setData(ClipboardData(text: copyValue)).then((_) {
                var message =
                    "${AppLocalizations.of(context)!.evm_copy}\n${AppLocalizations.of(context)!.reef_only}";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              });
            },
          ),
        ],
      ),
      const Gap(65),
    ]);
  }



  Widget buildBound() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Gap(16.0),
             Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Flexible(child: Text("Connecting to EVM address ..."))
            ],
          )],
        ),
      ]),
    );
  }

  Widget buildFundTransaction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: const CircularProgressIndicator(
                      color: Colors.purple,
                    ),
            ),
            const SizedBox(width: 12),
            Flexible(
                child: Text(nativeTxStatus??AppLocalizations.of(context)!.sending_tx_to_nw))
          ],
        )
      ],
    );
  }

  Widget buildBind() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!sendingBoundTransaction) ...[
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLocalizations.of(context)!.bind_modal_start_using_reef_evm),
          const Gap(8),
          Text(AppLocalizations.of(context)!.bind_modal_first_connect),
          const Gap(8)
        ]),
        // Bind for
        buildAccount(widget.bindFor),
        const Gap(16),
      ] else
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.purple,
              ),
            ),
            SizedBox(width: 12),
            Flexible(child: Text("Waiting for binding to complete..."))
          ],
        )
    ]);
  }

  Widget buildFund() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Other accounts with enough balance
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("~$MIN_BALANCE REEF ",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(AppLocalizations.of(context)!
                .bind_modal_is_needed_for_transaction),
          ]),
          const Gap(24),
          Text(AppLocalizations.of(context)!
              .bind_modal_coins_will_be_transferred),
          const Gap(8)
        ]),
        // Transfer from
        InkWell(
            onTap: () {
              if (availableTxAccounts.length > 1) {
                setState(() => selectAccount = true);
              }
            },
            child: (buildSelectAccount(widget.bindFor))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignatureContentToggle(
      SingleChildScrollView(
        child: Column(
          children: [
            if(!(jsConn && indexerConn && providerConn))
            GestureDetector(
              onTap: (){showReconnectProviderModal(AppLocalizations.of(context)!.connection_stats);},
              child: Text(AppLocalizations.of(context)!.connecting,style: Theme.of(context).textTheme.bodyLarge,)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32.0),
              child: ReefStepper(
                  currentStep: currentStep,
                  onStepContinue: () async {
                    switch (currentStep) {
                      case 0:
                        await startFunding();
                        setState(() {
                          sendingFundTransaction = true;
                        });
                        return;
                      case 1:
                        Future.delayed(const Duration(seconds: 1), () {
                          setState(() {
                            sendingBoundTransaction = true;
                          });
                        });
                        final value = await ReefAppState.instance.accountCtrl
                            .bindEvmAccount(widget.bindFor.address);
                        final resolvedEvmAdr = await ReefAppState.instance.accountCtrl
                            .resolveEvmAddress(widget.bindFor.address);
                        setState(() {
                          resolvedEvmAddress = resolvedEvmAdr;
                        });
                        if (value == null) {
                          sendingBoundTransaction=false;
                          return;
                        } else {
                          boundComplete = true;
                        }
                        break;
                      case 3:
                        Navigator.of(context).pop();
                        return;
                      default:
                    }

                    if (currentStep <= 2) {
                      setState(() {
                        currentStep += 1;
                        recordingChanges = true;
                      });
                      try {
                      var isEvmBounded = await ReefAppState.instance.accountCtrl.listenBindActivity(widget.bindFor.address);
                      if(isEvmBounded['updatedAccounts']['boundEvm'].length>0){
                          setState(() {
                          currentStep += 1;
                        });
                        if(widget.callback!=null)widget.callback!();
                        ReefAppState.instance.firebaseAnalyticsCtrl.logAnalytics("evm-bind-success");
                      }
                      } catch (e) {
                        print("boundEVM ERR=$e");
                        ReefAppState.instance.firebaseAnalyticsCtrl.logAnalytics("evm-bind-failed");
                      }
                    }
                  },
                  onStepCancel: () {
                    if (currentStep > 0) {
                      setState(() {
                        currentStep -= 1;
                      });
                    }
                  },
                  controlsBuilder: (context, details) {
                    final Color cancelColor;
                    switch (Theme.of(context).brightness) {
                      case Brightness.light:
                        cancelColor = Colors.black54;
                        break;
                      case Brightness.dark:
                        cancelColor = Colors.white70;
                        break;
                    }

                    final ThemeData themeData = Theme.of(context);
                    final ColorScheme colorScheme = themeData.colorScheme;
                    final MaterialLocalizations localizations =
                        MaterialLocalizations.of(context);

                    const OutlinedBorder buttonShape = RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(2)));
                    const EdgeInsets buttonPadding =
                        EdgeInsets.symmetric(horizontal: 16.0);

                    return ((currentStep == 0 && sendingFundTransaction && (statusValue != SendStatus.CANCELED &&
                              statusValue != SendStatus.ERROR)) ||
                            (currentStep == 1 && sendingBoundTransaction)) || (currentStep == 2 && recordingChanges)
                        ? const SizedBox()
                        : ElevatedButton(
                            child: Text(
                              details.isActive && details.currentStep >= 3
                                  ? AppLocalizations.of(context)!.continue_
                                  : localizations.continueButtonLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Styles.whiteColor
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              shadowColor: const Color(0x559d6cff),
                              elevation: 5,
                              backgroundColor: Styles.primaryAccentColor,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 32),
                            ),
                            onPressed: () async {
                              details.onStepContinue!();
                              if(widget.callback!=null)widget.callback!();
                            },
                          );
                  },
                  steps: [
                    ReefStep(
                        state: currentStep > 0
                            ? ReefStepState.complete
                            : ReefStepState.indexed,
                        title: Text(
                            AppLocalizations.of(context)!.select_account_for_funding),
                        content: sendingFundTransaction
                        && (statusValue != SendStatus.CANCELED &&
                              statusValue != SendStatus.ERROR)
                            ? buildFundTransaction()
                            : buildFund()),
                    ReefStep(
                        state: currentStep > 1
                            ? ReefStepState.complete
                            : ReefStepState.indexed,
                        title: Text(AppLocalizations.of(context)!.evm_connect_transaction),
                        content: buildBind()),
                    ReefStep(
                        state: (currentStep > 2)
                            ? ReefStepState.complete
                            : ReefStepState.indexed,
                        title: Text(AppLocalizations.of(context)!.evm_is_connected),
                        content: buildBound()),
                    ReefStep(
                        state: (currentStep == 3)
                            ? ReefStepState.complete
                            : ReefStepState.indexed,
                        title: Text(AppLocalizations.of(context)!.changes_recorded),
                        content: buildRecordedChanges()),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

void showBindEvmModal(BuildContext context, {required bindFor,callback}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: (() {
              var pendingSignatures = ReefAppState.instance.model.signatureRequests.list;
              if(pendingSignatures.length>0){
                ReefAppState.instance.signingCtrl
          .rejectSignature(pendingSignatures[0].signatureIdent);
              }else{
                Navigator.pop(context);
              }
            }),
          ),
          title: Text(AppLocalizations.of(context)!.connect_evm,style: TextStyle(color: Styles.whiteColor),),
          backgroundColor: Colors.purple,
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
        ),
        body: BindEvm(bindFor: bindFor,callback: callback,)),
  ));
}
