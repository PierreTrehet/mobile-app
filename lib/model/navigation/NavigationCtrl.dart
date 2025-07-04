import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reef_mobile_app/components/home/tx_info.dart';
import 'package:reef_mobile_app/model/navigation/homepage_navigation_model.dart';
import 'package:reef_mobile_app/model/navigation/nav_swipe_compute.dart';
import 'package:reef_mobile_app/model/navigation/navigation_model.dart';
import 'package:reef_mobile_app/pages/SplashScreen.dart';
import 'package:reef_mobile_app/pages/pools_page.dart';
import 'package:reef_mobile_app/pages/send_nft.dart';
import 'package:reef_mobile_app/pages/send_page.dart';
import 'package:reef_mobile_app/pages/swap_page_anukul.dart';
import 'package:reef_mobile_app/pages/wallet_connect_page.dart';
import 'package:reef_mobile_app/pages/wallet_connect_tx_page.dart';
import 'package:reef_mobile_app/utils/liquid_edge/liquid_carousel.dart';
import 'package:reef_mobile_app/utils/styles.dart';
import 'package:reef_mobile_app/flutter_gen/gen_l10n/app_localizations.dart';

import '../../components/sign/SignatureContentToggle.dart';

class NavigationCtrl with NavSwipeCompute {
  final NavigationModel _navigationModel;
  final HomePageNavigationModel _homePageNavigationModel;

  GlobalKey<LiquidCarouselState>? carouselKey;
  Future<bool>? _swipeComplete;
  bool _swiping = false;

  NavigationCtrl(this._navigationModel, this._homePageNavigationModel);

  void navigateHomePage(int index) => _homePageNavigationModel.navigate(index);

  void navigate(NavigationPage navigationPage) async {
    if (_swiping) return;

    if (_swipeComplete != null) {
      _swiping = true;
      await _swipeComplete;
      _swiping = false;
    }
    _swipeComplete = null;

    if (_navigationModel.currentPage == navigationPage) {
      _swiping = false;
      return;
    }
    final pageDiff = computeSwipeAnimation(
        currentPage: _navigationModel.currentPage, page: navigationPage);

    if (pageDiff.abs() > 1) {
      HapticFeedback.selectionClick();
      _swipeComplete = _swipePageTo(
          nr: pageDiff);
    } else {
      _swipeComplete = _swipePageTo(
          nr: pageDiff);
      HapticFeedback.selectionClick();
      _navigationModel.navigate(navigationPage);
    }
  }

  void navigateToSendPage(
      {required BuildContext context,
      required String preselected,
      String? preSelectedTransferAddress}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.send_tokens,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w500,
                      fontSize: 24,
                      color: Styles.whiteColor,
                    )),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
              ),
              body: SendPage(
                  preselected,
                  preSelectedTransferAddress: preSelectedTransferAddress,
                ),
               backgroundColor: Styles.greyColor,
              ),
             )));
  }


  void navigateToSendNFTPage(
      {required BuildContext context,
      required String nftUrl,
      required String name,
      required int balance,
      required String nftId,
      required String mimetype}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.send_nft,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w500,
                      fontSize: 24,
                      color: Styles.whiteColor
                    )),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
              ),
              backgroundColor: Styles.greyColor,
              body: 
              // Padding(
              //     padding:
              //         const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              //     child: 
                  SendNFT(nftUrl, name, balance, nftId, mimetype)
                  ),
            // )
            )
            ));
  }
  void navigateToTxInfo(
      {required BuildContext context,
      required String unparsedTimestamp,
      required String? imageUrl,
      required String? iconUrl,
      required String? mimetype}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.transaction_info,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w500,
                      fontSize: 24,
                      color: Styles.whiteColor
                    )),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
              ),
              body: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                child: TxInfo(unparsedTimestamp, imageUrl, iconUrl, mimetype),
              ),
              backgroundColor: Styles.greyColor,
            ))));
  }

  void navigateToSwapPage(
      {required BuildContext context, String? preselectedTop,String? preselectedBottom}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.swap_tokens,style: TextStyle(color: Styles.whiteColor),),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
              ),
              body: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                child: SwapPage(preselectedTop: preselectedTop,preselectedBottom:preselectedBottom),
              ),
              backgroundColor: Styles.greyColor,
            ))));
  }

  void  navigateToWalletConnectSignaturePage() {
    Navigator.of(navigatorKey.currentContext!).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text("WalletConnect",style: TextStyle(color: Styles.whiteColor),),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
                leading: SvgPicture.asset('assets/images/walletconnect.svg'),
              ),
              body: const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                child: WalletConnectTxPage(),
              ),
              backgroundColor: Styles.greyColor,
            ))));
  }

  void navigateToWalletConnectPage(
      {required BuildContext context}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text("WalletConnect",style: TextStyle(color: Styles.whiteColor),),
                backgroundColor: Colors.deepPurple.shade700,
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ),
              ),
              body: const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                child: WalletConnectPage(),
              ),
              backgroundColor: Styles.greyColor,
            ))));
  }
  void navigateToPoolsPage(
      {required BuildContext context}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SignatureContentToggle(Scaffold(
              appBar: AppBar(
                title: Text("Pools",style: TextStyle(color: Styles.whiteColor),),
                backgroundColor: Colors.deepPurple.shade700,
              ),
              body: const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                child: PoolsPage(),
              ),
              backgroundColor: Styles.greyColor,
            ))));
  }

  Future<bool> _swipePageTo(
      {required int nr}) async {
    if(nr>0) {
      for (var i =0;i<nr; i++) {
        await carouselKey?.currentState!.swipeXNext(x: nr);
      }
    }else {
      for (var i =0;i>nr; i--) {
        await carouselKey?.currentState!.swipeXPrevious(x: nr);
      }
    }
    return true;
  }

}
