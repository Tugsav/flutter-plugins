// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:flutter/cupertino.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'http_request_factory.dart';
import 'shims/dart_ui.dart' as ui;

/// Possible values for iFrame referrer policy.
enum ReferrerPolicy {
  // No referrer information will be sent along with a request.
  noReferrer,
  // Default. The referrer header will not be sent to origins without HTTPS.
  noReferrerWhenDowngrade,
  // Send only scheme, host, and port to the request client.
  origin,
  // For cross-origin requests: Send only scheme, host, and port. For same-origin requests: Also include the path.
  originWhenCrossOrigin,
  // For same-origin requests: Referrer info will be sent.
  // For cross-origin requests: No referrer info will be sent.
  sameOrigin,
  // Only send referrer info if the security level is the same (e.g. HTTPS to HTTPS).
  // Do not send to a less secure destination (e.g. HTTPS to HTTP).
  strictOrigin,
  // Send full path when performing a same-origin request. Send only origin when the security level stays the same (e.g. HTTPS to HTTPS).
  // Send no header to a less secure destination (HTTPS to HTTP).
  strictOriginWhenCrossOrigin,
  // Send origin, path and query string (but not fragment, password, or username). This value is considered unsafe
  unsafeUrl
}

/// An implementation of [PlatformWebViewControllerCreationParams] using Flutter
/// for Web API.
@immutable
class WebWebViewControllerCreationParams
    extends PlatformWebViewControllerCreationParams {
  /// Creates a new [WebWebViewControllerCreationParams] instance.
  WebWebViewControllerCreationParams({
    @visibleForTesting this.httpRequestFactory = const HttpRequestFactory(),
    this.iFrameReferrerPolicy = ReferrerPolicy.noReferrerWhenDowngrade,
  }) : super() {
    iFrame.referrerPolicy = _referrerPolicyNames[iFrameReferrerPolicy];
  }

  /// Creates a [WebWebViewControllerCreationParams] instance based on [PlatformWebViewControllerCreationParams].
  WebWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformWebViewControllerCreationParams params, {
    @visibleForTesting
        HttpRequestFactory httpRequestFactory = const HttpRequestFactory(),
  }) : this(
            httpRequestFactory: httpRequestFactory,
            iFrameReferrerPolicy: ReferrerPolicy.noReferrerWhenDowngrade);

  static int _nextIFrameId = 0;

  /// Handles creating and sending URL requests.
  final HttpRequestFactory httpRequestFactory;

  /// Selected referrer policy for the iFrame.
  final ReferrerPolicy iFrameReferrerPolicy;
  static final Map _referrerPolicyNames = {
    ReferrerPolicy.noReferrer: 'no-referrer',
    ReferrerPolicy.noReferrerWhenDowngrade: 'no-referrer-when-downgrade',
    ReferrerPolicy.origin: 'origin',
    ReferrerPolicy.originWhenCrossOrigin: 'origin-when-cross-origin',
    ReferrerPolicy.sameOrigin: 'same-origin',
    ReferrerPolicy.strictOrigin: 'strict-origin',
    ReferrerPolicy.strictOriginWhenCrossOrigin:
        'strict-origin-when-cross-origin',
    ReferrerPolicy.unsafeUrl: 'unsafe-url'
  };

  /// The underlying element used as the WebView.
  @visibleForTesting
  final IFrameElement iFrame = IFrameElement()
    ..id = 'webView${_nextIFrameId++}'
    ..width = '100%'
    ..height = '100%'
    ..style.border = 'none';
}

/// An implementation of [PlatformWebViewController] using Flutter for Web API.
class WebWebViewController extends PlatformWebViewController {
  /// Constructs a [WebWebViewController].
  WebWebViewController(PlatformWebViewControllerCreationParams params)
      : super.implementation(params is WebWebViewControllerCreationParams
            ? params
            : WebWebViewControllerCreationParams
                .fromPlatformWebViewControllerCreationParams(params));

  WebWebViewControllerCreationParams get _webWebViewParams =>
      params as WebWebViewControllerCreationParams;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    // ignore: unsafe_html
    _webWebViewParams.iFrame.src = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    if (!params.uri.hasScheme) {
      throw ArgumentError(
          'LoadRequestParams#uri is required to have a scheme.');
    }
    final HttpRequest httpReq =
        await _webWebViewParams.httpRequestFactory.request(
      params.uri.toString(),
      method: params.method.serialize(),
      requestHeaders: params.headers,
      sendData: params.body,
    );
    final String contentType =
        httpReq.getResponseHeader('content-type') ?? 'text/html';
    // ignore: unsafe_html
    _webWebViewParams.iFrame.src = Uri.dataFromString(
      httpReq.responseText ?? '',
      mimeType: contentType,
      encoding: utf8,
    ).toString();
  }
}

/// An implementation of [PlatformWebViewWidget] using Flutter the for Web API.
class WebWebViewWidget extends PlatformWebViewWidget {
  /// Constructs a [WebWebViewWidget].
  WebWebViewWidget(PlatformWebViewWidgetCreationParams params)
      : super.implementation(params) {
    final WebWebViewController controller =
        params.controller as WebWebViewController;
    ui.platformViewRegistry.registerViewFactory(
      controller._webWebViewParams.iFrame.id,
      (int viewId) => controller._webWebViewParams.iFrame,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: params.key,
      viewType: (params.controller as WebWebViewController)
          ._webWebViewParams
          .iFrame
          .id,
    );
  }
}
