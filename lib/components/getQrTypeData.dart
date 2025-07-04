import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:reef_mobile_app/components/modal.dart';
import 'package:reef_mobile_app/components/modals/change_password_modal.dart';
import 'package:reef_mobile_app/components/modals/import_account_from_qr.dart';
import 'package:reef_mobile_app/model/ReefAppState.dart';
import 'package:reef_mobile_app/utils/constants.dart';
import 'package:reef_mobile_app/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:reef_mobile_app/utils/functions.dart';
import 'package:reef_mobile_app/utils/password_manager.dart';
import 'package:reef_mobile_app/utils/styles.dart';
// import 'package:qr_code_tools/qr_code_tools.dart';

class QrDataDisplay extends StatefulWidget {
  ReefQrCodeType? expectedType;
  String? preselectedTokenAddress;

  QrDataDisplay(this.expectedType,this.preselectedTokenAddress, {Key? key}) : super(key: key);

  @override
  State<QrDataDisplay> createState() => _QrDataDisplayState();
}

class _QrDataDisplayState extends State<QrDataDisplay> {
  final GlobalKey _gLobalkey = GlobalKey();
  MobileScannerController? controller;
  ReefQrCode? qrCodeValue;
  String? qrTypeLabel;
  var numOfTrials = 3;

  String getHumanReadableQrType(ReefQrCodeType? type){
    switch(type){
       case ReefQrCodeType.address:
        return "Account Address QR Code";
      case ReefQrCodeType.accountJson:
        return "JSON File QR Code";
      case ReefQrCodeType.walletConnect:
        return "WalletConnect QR Code";
      default:
        return "Not a Reef QR Code";
    }
  }

  String getQrDataTypeMessage(ReefQrCodeType? type) {
    switch (type) {
      case ReefQrCodeType.address:
        return "This is Account Address , You can send funds here by scanning this QR Code";
      case ReefQrCodeType.accountJson:
        return "You can import this Account by scanning this QR code and entering the password.";
      case ReefQrCodeType.walletConnect:
        return "This is WalletConnect QR Code.";
      default:
        return "Not Reef QR Code.";
    }
  }

  void actOnQrCodeValue(ReefQrCode qrCode) async {
    switch (qrCode.type) {
      case ReefQrCodeType.address:
        // popping till it is first page or else there will be 2 send page in the stack if we use this widget on SendPage to scan and send
        Navigator.pop(context);
        while (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ReefAppState.instance.navigationCtrl.navigateToSendPage(
            context: context,
            preselected: widget.preselectedTokenAddress ?? Constants.REEF_TOKEN_ADDRESS,
            preSelectedTransferAddress: qrCode.data);
        break;
      case ReefQrCodeType.accountJson:
        Navigator.pop(context);
        if (await PasswordManager.checkIfPassword()) {
          showImportAccountQrModal(data: qrCode);
        } else {
          showModal(context,
              headText: "Choose Password",
              child: ChangePassword(
                onChanged: () => showImportAccountQrModal(data: qrCode),
              ));
        }
        break;
      case ReefQrCodeType.walletConnect:
        Navigator.pop(context);
          final Uri uriData = Uri.parse(qrCode.data);
          await ReefAppState.instance.walletConnect.getWeb3Wallet().pair(
            uri: uriData,
          );
        break;

      default:
        break;
    }
  }

  Future<void> handleQrCodeData(String qrCodeData) async {
    ReefQrCode? qrCode;

    // TODO: Test `reefApp:` deep link with web3Modal once Reef app is added to explorer
    if (qrCodeData.startsWith("wc:") || qrCodeData.startsWith("reefApp:")) {
      qrCode = ReefQrCode(ReefQrCodeType.walletConnect, qrCodeData);
    } else {
      try {
        var decoded = jsonDecode(qrCodeData);
        var qrCodeType = ReefQrCodeType.values.byName(decoded["type"]);
        qrCode = ReefQrCode(qrCodeType, decoded["data"]);
      } on FormatException catch (e) {
        var isAddr = await ReefAppState.instance.accountCtrl
            .isValidSubstrateAddress(qrCodeData);
        if (isAddr && isReefAddrPrefix(qrCodeData)) {
          qrCode = ReefQrCode(ReefQrCodeType.address, qrCodeData);
        }
      }
    }

    setState(() {
      qrCodeValue = qrCode ?? ReefQrCode(ReefQrCodeType.invalid, "");
      if (widget.expectedType != null &&
          widget.expectedType == qrCodeValue?.type) {
        actOnQrCodeValue(qrCodeValue!);
        return;
      }
      // when account qr code is captured in camera frame
      if(widget.expectedType==ReefQrCodeType.walletConnect && widget.expectedType!=qrCodeValue?.type){
        qrTypeLabel = "Please place device correctly, detected ${getHumanReadableQrType(qrCodeValue?.type)} instead of WalletConnect.";
        return;
      }
      qrTypeLabel = getQrDataTypeMessage(qrCodeValue?.type);
    });
  }

  void qr(MobileScannerController controller) async {
    this.controller = controller;
    var scanRes = await controller.barcodes.first;
    await handleQrCodeData(scanRes.barcodes.first.rawValue!);
    this.controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MaterialButton(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () {
                Navigator.of(context).pop();
              },
              padding: const EdgeInsets.all(2),
              child: Column(
                children: [
                  if (qrCodeValue == null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Center(
                            child: Container(
                              width: 400,
                              height: 300,
                              child:
                              MobileScanner(key: _gLobalkey, controller: controller,
                              onDetect: (BarcodeCapture barcodeData) async {
                                var scanRes = barcodeData.barcodes.first;
                                await handleQrCodeData(scanRes.rawValue!);
                              },),
                            ),
                          ),
                        ),
                        Gap(16.0),
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.crop_free,color: Styles.whiteColor),
                            label: Text(
                              AppLocalizations.of(context)!.scan_from_image,
                              style: TextStyle(
                                fontSize: 12,
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
                                  vertical: 12, horizontal: 28),
                            ),
                            onPressed: () async {
                              try {
                                final res = await scanFile();
                                if (res != Null) {
                                  await handleQrCodeData(res!);
                                }
                              } catch (e) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("No Reef QR code")));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  if (qrCodeValue != null)
                    Column(
                      children: [
                        Text(qrTypeLabel ?? ''),
                        Gap(16.0),
                        ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    shadowColor: const Color(0x559d6cff),
                    elevation: 5,
                    backgroundColor: Styles.primaryAccentColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 28),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showQrTypeDataModal(
                    AppLocalizations.of(context)!.scan_qr_code, context,
                    expectedType: ReefQrCodeType.walletConnect);},
                  child: Text(
                    "Scan again",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Styles.whiteColor
                    ),
                  ),
                ),
                        if (qrCodeValue?.type != ReefQrCodeType.invalid &&
                            widget.expectedType == ReefQrCodeType.info)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40)),
                                shadowColor: const Color(0x559d6cff),
                                elevation: 5,
                                backgroundColor: const Color(0xff9d6cff),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () {
                                actOnQrCodeValue(qrCodeValue!);
                              },
                              child: Builder(builder: (context) {
                                return Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              }),
                            ),
                          ),
                        if (widget.expectedType == qrCodeValue?.type)
                          CircularProgressIndicator(
                            color: Styles.primaryAccentColor,
                          ),
                      ],
                    )
                ],
              ),
            ),
            const Gap(8),
          ],
        ));
  }
}

void showQrTypeDataModal(String title, BuildContext context,
    {ReefQrCodeType? expectedType,String? preselectedTokenAddress}) {
  showModal(context, child: QrDataDisplay(expectedType,preselectedTokenAddress), headText: title);
}

class ReefQrCode {
  final ReefQrCodeType type;
  final String data;

  const ReefQrCode(this.type, this.data);
}

Future<String?> scanFile() async {
  // Used to pick a file from device storage
  try {
    final pickedFile = await FilePicker.platform
      .pickFiles(type: FileType.image); //can pick image files only
  if (pickedFile != null) {
    final filePath = pickedFile.files.single.path;
    if (filePath != null) {
      // var res = await QrCodeToolsPlugin.decodeFrom(filePath);
      var res = await MobileScannerController().analyzeImage(filePath);
      debugPrint('${res?.barcodes.first.rawValue}');
      return res?.barcodes.first.rawValue;
    }
  }
  } catch (e) {
    print("scanFile ERR===${e}");
  }
  
}

enum ReefQrCodeType { address, accountJson, info, walletConnect, invalid }
