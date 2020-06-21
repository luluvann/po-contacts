import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:po_contacts_flutter/utils/cloud_sync/interface/sync_interface_google_drive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:po_contacts_flutter/utils/cloud_sync/sync_exception.dart';
import 'package:url_launcher/url_launcher.dart';

class _OAuthCodeData {
  final String device_code;
  final String user_code;
  final String verification_url;
  final int expires_in;
  final int interval;

  _OAuthCodeData(
    this.device_code,
    this.user_code,
    this.verification_url,
    this.expires_in,
    this.interval,
  );
}

class _OAuthCreateTokenData {
  final String access_token;
  final String refresh_token;

  _OAuthCreateTokenData(
    this.access_token,
    this.refresh_token,
  );
}

class SyncInterfaceForGoogleDriveCodeBasedAuth {
  static const String _GOOGLE_DRIVE_ACCESS_TOKEN = 'google_drive_access_token';
  static const String _GOOGLE_DRIVE_REFRESH_TOKEN = 'google_drive_refresh_token';

  static final Future<SharedPreferences> _sharedPreferences = SharedPreferences.getInstance();

  static Future<String> _getAccessToken() async {
    return (await _sharedPreferences).getString(_GOOGLE_DRIVE_ACCESS_TOKEN);
  }

  static Future<void> _setAccessToken(final String accessToken) async {
    await (await _sharedPreferences).setString(_GOOGLE_DRIVE_ACCESS_TOKEN, accessToken);
  }

  static Future<String> _getRefreshToken() async {
    return (await _sharedPreferences).getString(_GOOGLE_DRIVE_REFRESH_TOKEN);
  }

  static Future<void> _setRefreshToken(final String refreshToken) async {
    await (await _sharedPreferences).setString(_GOOGLE_DRIVE_REFRESH_TOKEN, refreshToken);
  }

  static Future<bool> _isAccessTokenValid(final String accessToken) async {
    if (accessToken == null) {
      return false;
    }
    final http.Response httpGetResponse = await http.get(
      'https://www.googleapis.com/drive/v2/about',
      headers: {
        'Authorization': accessToken,
        'Accept': 'application/json',
      },
    );
    if (httpGetResponse.statusCode == 200) {
      return true;
    } else if (httpGetResponse.statusCode == 401 || httpGetResponse.statusCode == 403) {
      return false;
    } else {
      throw SyncException(
        SyncExceptionType.SERVER,
        message:
            'SyncInterfaceForGoogleDriveCodeBasedAuth._isAccessTokenValid failed status code ${httpGetResponse.statusCode}',
      );
    }
  }

  static Future<String> _getRefreshedAccessToken(
    final String clientId,
    final String clientSecret,
    final String refreshToken,
  ) async {
    if (refreshToken == null) {
      return null;
    }
    final http.Response httpPostResponse = await http.post(
      'https://oauth2.googleapis.com/token',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=refresh_token' +
          '&client_id=' +
          Uri.encodeComponent(clientId) +
          '&client_secret=' +
          Uri.encodeComponent(clientSecret) +
          '&refresh_token=' +
          Uri.encodeComponent(refreshToken),
    );
    if (httpPostResponse.statusCode == 200) {
      final Map<String, dynamic> httpPostResponseJSON = jsonDecode(httpPostResponse.body);
      return httpPostResponseJSON['token_type'] + ' ' + httpPostResponseJSON['access_token'];
    } else {
      return null;
    }
  }

  static Future<_OAuthCodeData> _createNewOAuthCodeData(final String clientId) async {
    final http.Response httpPostResponse = await http.post(
      'https://oauth2.googleapis.com/device/code',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'scope=' +
          Uri.encodeComponent('email https://www.googleapis.com/auth/drive.file') +
          '&client_id=' +
          Uri.encodeComponent(clientId),
    );
    if (httpPostResponse.statusCode == 200) {
      final Map<String, dynamic> httpPostResponseJSON = jsonDecode(httpPostResponse.body);
      return _OAuthCodeData(
        httpPostResponseJSON['device_code'],
        httpPostResponseJSON['user_code'],
        httpPostResponseJSON['verification_url'],
        httpPostResponseJSON['expires_in'],
        httpPostResponseJSON['interval'],
      );
    } else {
      return null;
    }
  }

  static Future<_OAuthCreateTokenData> _createNewOAuthToken(
    final String clientId,
    final String clientSecret,
    final _OAuthCodeData oAuthCodeData,
  ) async {
    if (oAuthCodeData == null) {
      return null;
    }
    final http.Response httpPostResponse = await http.post(
      'https://oauth2.googleapis.com/token',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=http://oauth.net/grant_type/device/1.0' +
          '&client_id=' +
          Uri.encodeComponent(clientId) +
          '&client_secret=' +
          Uri.encodeComponent(clientSecret) +
          '&code=' +
          Uri.encodeComponent(oAuthCodeData.device_code),
    );
    if (httpPostResponse.statusCode == 200) {
      final Map<String, dynamic> httpPostResponseJSON = jsonDecode(httpPostResponse.body);
      return _OAuthCreateTokenData(
        httpPostResponseJSON['token_type'] + ' ' + httpPostResponseJSON['access_token'],
        httpPostResponseJSON['refresh_token'],
      );
    } else {
      return null;
    }
  }

  /// Prompts the user to open the browser after copying a user code
  /// If the user proceeds with opening the browser, the result will be true
  /// If the user requests to cancel, the result will be false
  static Future<bool> _openVerificationUrlIntoBrowser(
      final SyncInterfaceForGoogleDrive gdsi, final _OAuthCodeData oAuthCodeData) {
    final BuildContext currentContext = gdsi.uiController.getUIBuildContext();
    final Completer<bool> futureBrowserOpened = Completer<bool>();
    showDialog<Object>(
        context: currentContext,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(gdsi.uiController.googleAuthDialogTitleText),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(gdsi.uiController.googleAuthDialogMessageText),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        oAuthCodeData.user_code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(gdsi.uiController.googleAuthCancelButtonText),
                onPressed: () {
                  Navigator.of(context).pop();
                  futureBrowserOpened.complete(false);
                },
              ),
              FlatButton(
                child: Text(gdsi.uiController.googleAuthDialogCopyCodeButtonText),
                onPressed: () {
                  gdsi.uiController.copyTextToClipBoard(oAuthCodeData.user_code);
                },
              ),
              FlatButton(
                child: Text(gdsi.uiController.googleAuthDialogOpenBrowserButtonText),
                onPressed: () {
                  Navigator.of(context).pop();
                  launch(oAuthCodeData.verification_url);
                  futureBrowserOpened.complete(true);
                },
              ),
            ],
          );
        });
    return futureBrowserOpened.future;
  }

  /// Prompts the user for confirmation to proceed with continuing authentication
  /// If the user proceeds with continuing, the result will be true
  /// If the user requests to restart the process, the result will be false
  /// If the user requests to cancel, the result will be null
  static Future<bool> _askForAuthContinuation(
      final SyncInterfaceForGoogleDrive gdsi, final _OAuthCodeData oAuthCodeData) {
    final BuildContext currentContext = gdsi.uiController.getUIBuildContext();
    final Completer<bool> futureContinuationChoice = Completer<bool>();
    showDialog<Object>(
        context: currentContext,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(gdsi.uiController.continueGoogleAuthDialogTitleText),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(gdsi.uiController.continueGoogleAuthDialogMessageText),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(gdsi.uiController.googleAuthCancelButtonText),
                onPressed: () {
                  Navigator.of(context).pop();
                  futureContinuationChoice.complete(null);
                },
              ),
              FlatButton(
                child: Text(gdsi.uiController.continueGoogleAuthDialogRestartButtonText),
                onPressed: () {
                  Navigator.of(context).pop();
                  futureContinuationChoice.complete(false);
                },
              ),
              FlatButton(
                child: Text(gdsi.uiController.continueGoogleAuthDialogProceedButtonText),
                onPressed: () {
                  Navigator.of(context).pop();
                  futureContinuationChoice.complete(true);
                },
              ),
            ],
          );
        });
    return futureContinuationChoice.future;
  }

  static Future<String> authenticateWithCode(final SyncInterfaceForGoogleDrive gdsi, final bool allowUI) async {
    final String accessToken = await _getAccessToken();
    if (await _isAccessTokenValid(accessToken)) {
      return accessToken;
    }
    final String clientId = gdsi.config.clientId;
    final String clientSecret = gdsi.config.clientSecret;
    final String refreshToken = await _getRefreshToken();
    final String refreshedAccessToken = await _getRefreshedAccessToken(
      clientId,
      clientSecret,
      refreshToken,
    );
    if (refreshedAccessToken != null) {
      await _setAccessToken(refreshedAccessToken);
      return refreshedAccessToken;
    }
    if (!allowUI) {
      return null;
    }

    bool retry = true;

    final _OAuthCodeData oAuthCodeData = await _createNewOAuthCodeData(clientId);
    if (oAuthCodeData == null) {
      return null;
    }

    while (retry) {
      final bool browserOpen = await _openVerificationUrlIntoBrowser(gdsi, oAuthCodeData);
      if (!browserOpen) {
        return null;
      }
      final bool continuationChoice = await _askForAuthContinuation(gdsi, oAuthCodeData);
      if (continuationChoice == null) {
        return null;
      } else {
        retry = !continuationChoice;
      }
    }

    final _OAuthCreateTokenData createdTokenData = await _createNewOAuthToken(clientId, clientSecret, oAuthCodeData);

    if (createdTokenData == null) {
      return null;
    }

    await _setRefreshToken(createdTokenData.refresh_token);
    await _setAccessToken(createdTokenData.access_token);
    return createdTokenData.access_token;
  }
}
