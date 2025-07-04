import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reef_mobile_app/components/InsufficientBalance.dart';
import 'package:reef_mobile_app/components/modal.dart';
import 'package:reef_mobile_app/model/ReefAppState.dart';
import 'package:reef_mobile_app/utils/ipfs.dart';
import 'package:reef_mobile_app/utils/styles.dart';
import 'package:reef_mobile_app/flutter_gen/gen_l10n/app_localizations.dart';

import '../components/sign/SignatureContentToggle.dart';

class PoolsPage extends StatefulWidget {
  const PoolsPage({super.key});

  @override
  State<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends State<PoolsPage> {
  List<dynamic> _pools = ReefAppState.instance.poolsCtrl.getCachedPools();
  Map<String, dynamic> tokenBalances = {};
  int offset = 0;
  bool isLoading = false;

  // searched pools
  List<dynamic>? searchedPools;
  String searchInput = "";
  bool searched = false;
  bool displaySearchModal = false;
  // bool filterSwappable = false;

  // filtering pools
  bool hasReef = false; //if user has reef display only swappable

  // search input listeners
  bool _isSearchEditing = false;

  FocusNode _focusNodeSearch = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNodeSearch.addListener(_onFocusSearchChange);
    _searchController.text = searchInput;
    _searchController.addListener(() {
      setState(() {
        searchInput = _searchController.text;
        searched = searchInput.isNotEmpty;
        searchPools(searchInput);
      });
    });
    _fetchUserBalance();
    _fetchTokensAndPools();
  }

  void _fetchUserBalance() {
    try {
      var selectedAccount = ReefAppState.instance.model.accounts.accountsList
          .firstWhere((account) =>
              account.address ==
              ReefAppState.instance.model.accounts.selectedAddress);
      if (selectedAccount.balance > BigInt.zero) {
        setState(() {
          hasReef = true;
        });
      }
    } catch (e) {
      print("error in fetching selected account ${e}");
    }
  }

  void clearSearch() {
    setState(() {
      searchInput = "";
      _searchController.text = "";
      searched = false;
    });
    searchPools("");
  }

  void searchPools(String val) async {
    final searchedPoolsRes =
        await ReefAppState.instance.poolsCtrl.getPools(0, val);
    setState(() {
      searchedPools = searchedPoolsRes;
    });
  }

  void _onFocusSearchChange() {
    setState(() {
      _isSearchEditing = !_isSearchEditing;
    });
  }

  void _fetchTokensAndPools() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    var selectedTokens = ReefAppState.instance.model.tokens.selectedErc20List;
    for (var token in selectedTokens) {
      tokenBalances[token.address] = token.balance;
    }
    final pools = offset == 0
        ? []
        : await ReefAppState.instance.poolsCtrl.getPools(offset, "");
    if (pools is List<dynamic>) {
      ReefAppState.instance.poolsCtrl.appendPools(pools);
      setState(() {
        offset += 10;
        isLoading = false;
      });
    }
  }

  bool hasBalance(String addr) {
    return tokenBalances.containsKey(addr) &&
        tokenBalances[addr] > BigInt.from(0);
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
    _focusNodeSearch.removeListener(_onFocusSearchChange);
    _focusNodeSearch.dispose();
  }

  Widget getPoolCard(dynamic pool) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Container(
                width: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    buildIcon(pool['iconUrl1'], 0),
                    Positioned(
                        left: 14, child: buildIcon(pool['iconUrl2'], 14)),
                  ],
                ),
              ),
              title: Text('${pool['name1']} - ${pool['name2']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${pool['symbol1']}/${pool['symbol2']}'),
                  SizedBox(width: 4),
                  Tooltip(
                    message: '${pool['token1']}/\n${pool['token2']}',
                    textStyle: TextStyle(
                      fontSize: 12.0,
                      color: Colors.white,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.help_outline,
                      size: 18.0,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('TVL : ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.0)),
                      Text('\$${pool["tvl"]}',
                          style: TextStyle(fontSize: 12.0)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('24h Vol. : ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.0)),
                      Text('\$ ${pool['volume24h']}',
                          style: TextStyle(fontSize: 12.0)),
                      Text(' ${pool['volumeChange24h']} %',
                          style: TextStyle(
                              fontSize: 12.0,
                              color: Styles.greenColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            if (hasBalance(pool['token1']) || hasBalance(pool['token2']))
              Container(
                margin: EdgeInsets.only(
                    top: 8.0, left: 16.0, right: 16.0, bottom: 8.0),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                        color: Styles.secondaryAccentColorDark,
                        spreadRadius: -10,
                        offset: Offset(0, 5),
                        blurRadius: 20),
                  ],
                  borderRadius: BorderRadius.circular(80),
                  gradient: LinearGradient(
                    colors: [
                      Styles.purpleColorLight,
                      Styles.secondaryAccentColorDark
                    ],
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                  ),
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(
                    CupertinoIcons.repeat,
                    color: Colors.white,
                    size: 16.0,
                  ),
                  style: ElevatedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.transparent,
                      shape: const StadiumBorder(),
                      elevation: 0),
                  label: Text(
                    "Swap",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    ReefAppState.instance.navigationCtrl.navigateToSwapPage(
                        context: context,
                        preselectedTop: pool['token1'],
                        preselectedBottom: pool['token2']);
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget buildLoader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget buildSearchAcknowledge() {
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          searchedPools == null
              ? Text(
                  "Search pools for ${searchInput} ...",
                  style: TextStyle(
                      color: Styles.textLightColor,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w800),
                )
              : searchedPools!.isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.error, size: 14.0, color: Styles.errorColor),
                        const Gap(4.0),
                        Text(
                          "No pools found for ${searchInput}!",
                          style: TextStyle(
                              color: Styles.errorColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                      ],
                    )
                  : Text(
                      "Search Results for ${searchInput} ( ${searchedPools?.length} )",
                      style: TextStyle(
                          color: Styles.textLightColor,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800),
                    ),
          GestureDetector(
            onTap: () {
              clearSearch();
            },
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Styles.buttonColor),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: Styles.whiteColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchContainer() {
    return Column(
      children: [
        Gap(16),
        Row(
          children: [
            Gap(4.0),
            Expanded(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Styles.whiteColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x20000000),
                    width: 1,
                  ),
                ),
                child: TextField(
                  focusNode: _focusNodeSearch,
                  controller: _searchController,
                  decoration:
                      const InputDecoration.collapsed(hintText: 'Search'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        Gap(4.0),
        if (searched) buildSearchAcknowledge(),
        Gap(4.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignatureContentToggle(
      Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            color: Styles.darkBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.pools,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w500,
                        fontSize: 32,
                        color: Colors.grey.shade100,
                      ),
                    ),
                    Row(
                      children: [
                        // GestureDetector(
                        //   onTap: () {
                        //     setState(() {
                        //       filterSwappable = true;
                        //     });
                        //   },
                        //   child: Container(
                        //     decoration: BoxDecoration(
                        //       borderRadius: BorderRadius.circular(20),
                        //       color: Styles.boxBackgroundColor,
                        //     ),
                        //     child: Padding(
                        //       padding: const EdgeInsets.all(8.0),
                        //       child: Icon(
                        //         Icons.sort,
                        //         size: 18,
                        //         color: Styles.textLightColor,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // Gap(8.0),
                        // GestureDetector(
                        //   onTap: () {
                        //     setState(() {
                        //       displaySearchModal = true;
                        //     });
                        //   },
                        //   child: Container(
                        //     decoration: BoxDecoration(
                        //         borderRadius: BorderRadius.circular(20),
                        //         gradient: Styles.buttonGradient),
                        //     child: Padding(
                        //       padding: const EdgeInsets.all(8.0),
                        //       child: Icon(
                        //         Icons.search,
                        //         size: 18,
                        //         color: Styles.whiteColor,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
                // if(filterSwappable)
                // Container(
                //   padding: EdgeInsets.only(bottom: 4.0),
                //   child: Row(
                //     children: [
                //       Text(
                //         "Filter applied ",
                //         style: TextStyle(
                //             color: Styles.textLightColor,
                //             fontWeight: FontWeight.bold),
                //       ),
                //       Container(
                //         padding: EdgeInsets.only(
                //             top: 4.0, bottom: 4.0, left: 12.0, right: 12.0),
                //         decoration: BoxDecoration(
                //           color: Styles.whiteColor,
                //           borderRadius: BorderRadius.circular(12.0),
                //         ),
                //         child: Row(
                //           children: [
                //             Text(
                //               "can swap",
                //               style: TextStyle(
                //                   color: Styles.textLightColor,
                //                   fontSize: 12,
                //                   fontWeight: FontWeight.w600),
                //             ),
                //             Gap(8.0),
                //             GestureDetector(
                //               onTap: (){
                //                 setState(() {
                //                   filterSwappable=false;
                //                 });
                //               },
                //                 child: Container(
                //               decoration: BoxDecoration(
                //                   color: Styles.greyColor,
                //                   borderRadius: BorderRadius.circular(20)),
                //               child: Padding(
                //                 padding: const EdgeInsets.all(2.0),
                //                 child: Icon(CupertinoIcons.xmark,
                //                     color: Colors.black87, size: 12),
                //               ),
                //             )),
                //           ],
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                if (hasReef)
                  Column(
                    children: [
                      Gap(8.0),
                      buildSearchContainer(),
                      Gap(8.0),
                    ],
                  ),
                if (!hasReef)
                  Container(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: InsufficientBalance(
                              customText: "Get REEFs to swap tokens",
                            ))
                          ],
                        ),
                        Gap(16.0)
                      ],
                    ),
                  ),
                Flexible(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!isLoading &&
                          scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                        _fetchTokensAndPools();
                      }
                      return true;
                    },
                    child: searchedPools != null && searchedPools!.isNotEmpty
                        ? Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: searchedPools!.length,
                              itemBuilder: (context, index) {
                                var pool = searchedPools![index];
                                if (hasReef) {
                                  if (hasBalance(pool['token1']) ||
                                      hasBalance(pool['token2']))
                                    return getPoolCard(pool);
                                  else
                                    return Container();
                                }
                                // return getPoolCard(pool);
                              },
                            ),
                          )
                        : _pools.isNotEmpty
                            ? ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _pools.length,
                                itemBuilder: (context, index) {
                                  var pool = _pools[index];
                                  //                             if(filterSwappable){
                                  //   if(hasBalance(pool['token1']) || hasBalance(pool['token2']))return getPoolCard(pool);
                                  //   else return Container();
                                  // }else{
                                  if (hasReef) {
                                    if (hasBalance(pool['token1']) ||
                                        hasBalance(pool['token2']))
                                      return getPoolCard(pool);
                                    else
                                      return Container();
                                  }
                                  return getPoolCard(pool);
                                  // }
                                },
                              )
                            : Center(
                                child: CircularProgressIndicator(
                                    color: Styles.primaryColor)),
                  ),
                ),
                if (isLoading && _pools.isNotEmpty) buildLoader()
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIcon(String dataUrl, double positionOffset) {
    return ClipOval(
      child: isValidSVG(dataUrl)
          ? SvgPicture.string(
              utf8.decode(base64
                  .decode(dataUrl.split('data:image/svg+xml;base64,')[1])),
              width: 30,
              height: 30)
          : Image.network(dataUrl, width: 30, height: 30, fit: BoxFit.cover),
    );
  }

  bool isValidSVG(String? dataUrl) {
    return dataUrl != null && dataUrl.contains("data:image/svg+xml;base64,");
  }
}
