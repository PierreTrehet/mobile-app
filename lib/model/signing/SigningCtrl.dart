import 'dart:async';
import 'dart:convert';

import 'package:local_auth/local_auth.dart';
import 'package:mobx/src/api/store.dart';
import 'package:reef_chain_flutter/js_api_service.dart';
import 'package:reef_chain_flutter/reef_api.dart';
import 'package:reef_mobile_app/model/ReefAppState.dart';
import 'package:reef_mobile_app/model/account/ReefAccount.dart';
import 'package:reef_mobile_app/model/signing/signature_request.dart';
import 'package:reef_mobile_app/model/signing/signature_requests.dart';
import 'package:reef_mobile_app/model/signing/signer_payload_json.dart';
import 'package:reef_mobile_app/model/signing/signer_payload_raw.dart';
import 'package:reef_mobile_app/model/signing/tx_decoded_data.dart';
import 'package:reef_mobile_app/model/status-data-object/StatusDataObject.dart';
import 'package:reef_mobile_app/service/StorageService.dart';
import 'package:reef_mobile_app/utils/functions.dart';

import '../StorageKey.dart';
import '../account/account_model.dart';

class SigningCtrl {
  static final SIGN_ERR_CANCELED = "_canceled";
  static final SIGN_ERR_EMPTY_MNEMONIC = "_empty-mnemonic-value";
  final SignatureRequests signatureRequests;
  final StorageService storage;
  static final LocalAuthentication localAuth = LocalAuthentication();
  final AccountModel accountModel;
  final ReefChainApi reefChainApi;

  SigningCtrl(this.storage, this.signatureRequests, this.accountModel,this.reefChainApi) {
    reefChainApi.reefState.signingApi.jsTxSignatureConfirmationMessageSubj.listen((jsApiMessage) {
      var signatureRequest = _buildSignatureRequest(jsApiMessage);
      if (signatureRequest.payload is SignerPayloadJSON) {
        signatureRequest.decodeMethod();
      }
      signatureRequests.add(signatureRequest);
    });
  }

  Future<bool> authenticateAndSign(SignatureRequest signatureRequest, String? verifyPassword) async {
    bool authenticated = false;

    if (await checkBiometricsSupport() && verifyPassword==null) {
      authenticated = await _authenticateWithBiometrics(signatureRequest);
    } else {
      authenticated = await _authenticateWithPassword( signatureRequest, verifyPassword);
    }
    if (authenticated == true){
      _confirmSignature(
        signatureRequest.signatureIdent,
        signatureRequest.payload.address,
      );
    }
    return authenticated;
  }

  Future<dynamic> signRaw(String address, String message) =>
      reefChainApi.reefState.signingApi.signRaw(address, message);

  Future<dynamic> signPayload(String address, Map<String, dynamic> payload) =>
      reefChainApi.reefState.signingApi.signPayload(address, payload);

  Future<dynamic> decodeMethod(String data, {dynamic types})=>types==null?reefChainApi.reefState.signingApi.decodeMethod(data) : 
  reefChainApi.reefState.signingApi.decodeMethod(data,types:jsonEncode(types));

  Future<dynamic> bytesString(String bytes) =>
      reefChainApi.reefState.signingApi.bytesString(bytes);

  Future<void> _confirmSignature(
      String sigConfirmationIdent, String address) async {
    var account = await storage.getAccount(address);
    if (account == null) {
      print("ERROR: confirmSignature - Account not found.");
      return;
    }
    signatureRequests.remove(sigConfirmationIdent);
    reefChainApi.reefState.signingApi.confirmTxSignature(sigConfirmationIdent, account.mnemonic);
  }

  Future<dynamic> sendNFT(String unresolvedFrom, String nftContractAddress,
      String from, String to, int nftAmount, int nftId) async {
    return reefChainApi.reefState.signingApi.sendNFT(unresolvedFrom, nftContractAddress, from, to, nftAmount, nftId);
  }

  Future<dynamic> getTypes(String genesisHash, String specVersion)async{
    dynamic types;
    var metadata = await storage
        .getMetadata(genesisHash);
    if (metadata != null &&
        metadata.specVersion ==
            int.parse(specVersion.substring(2), radix: 16)) {
      types = metadata.types;
    }
    return types;
  }

  SignatureRequest _buildSignatureRequest(JsApiMessage jsApiMessage) {
    var signatureIdent = jsApiMessage.reqId;
    Store payload;
    if (jsApiMessage.value["data"] != null) {
      payload = SignerPayloadRaw(jsApiMessage.value["address"],
          jsApiMessage.value["data"], jsApiMessage.value["type"]);
    } else {
      payload = SignerPayloadJSON(
          jsApiMessage.value["address"],
          jsApiMessage.value["blockHash"],
          jsApiMessage.value["blockNumber"],
          jsApiMessage.value["era"],
          jsApiMessage.value["genesisHash"],
          jsApiMessage.value["method"],
          jsApiMessage.value["nonce"],
          jsApiMessage.value["specVersion"],
          jsApiMessage.value["tip"],
          jsApiMessage.value["transactionVersion"],
          jsApiMessage.value["signedExtensions"].cast<String>(),
          jsApiMessage.value["version"]);
    }

    return SignatureRequest(signatureIdent, payload, this);
  }

  void rejectSignature(String signatureIdent) {
    signatureRequests.remove(signatureIdent);
    reefChainApi.reefState.signingApi.rejectTxSignature(signatureIdent);
  }

  Future<TxDecodedData> getTxDecodedData(dynamic payload, dynamic decodedMethod) async {
  TxDecodedData txDecodedData = TxDecodedData(
    specVersion: hexToDecimalString(payload.specVersion),
    nonce: hexToDecimalString(payload.nonce),
  );

    txDecodedData.genesisHash = payload.genesisHash;

    txDecodedData.methodName = decodedMethod["methodName"];
    const jsonEncoder = JsonEncoder.withIndent("  ");
    txDecodedData.args = jsonEncoder.convert(decodedMethod["args"]);
    txDecodedData.info = decodedMethod["info"];

    txDecodedData.rawMethodData = payload.method;

  if (payload.tip != null) {
    txDecodedData.tip = hexToDecimalString(payload.tip);
  }
  return txDecodedData;
}

  Future<bool> checkBiometricsSupport() async {
    final isDeviceSupported = await localAuth.isDeviceSupported();
    final isAvailable = await localAuth.canCheckBiometrics;
    return isAvailable && isDeviceSupported;
  }

  Future<bool> _authenticateWithBiometrics(SignatureRequest signatureReq) async {
    getSignatureSigner(signatureReq);

    return localAuth.authenticate(
        localizedReason: 'Authenticate with biometrics',
        options: const AuthenticationOptions(
            useErrorDialogs: true, stickyAuth: true, biometricOnly: true));
  }

  Future<bool> _authenticateWithPassword(SignatureRequest signatureReq, String? value) async {
    if(value==null || value.isEmpty) {
      return false;
    }
    getSignatureSigner(signatureReq);
    final storedPassword =
    await storage.getValue(StorageKey.password.name);
    return storedPassword == value;
  }

  StatusDataObject<ReefAccount> getSignatureSigner(SignatureRequest signatureReq) {
    final signer = accountModel.accountsFDM.data
        .firstWhere((acc) => acc.data.address == signatureReq?.payload.address,
        orElse: () => throw Exception("Signer not found"));
    return signer;
  }

  bool isTransaction(SignatureRequest signatureRequest){
    return signatureRequest.payload.type== "bytes";
  }
}