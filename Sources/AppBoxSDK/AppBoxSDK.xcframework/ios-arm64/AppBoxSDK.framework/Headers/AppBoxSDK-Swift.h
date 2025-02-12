#if 0
#elif defined(__arm64__) && __arm64__
// Generated by Apple Swift version 5.10 (swiftlang-5.10.0.13 clang-1500.3.9.4)
#ifndef APPBOXSDK_SWIFT_H
#define APPBOXSDK_SWIFT_H
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"

#if !defined(__has_include)
# define __has_include(x) 0
#endif
#if !defined(__has_attribute)
# define __has_attribute(x) 0
#endif
#if !defined(__has_feature)
# define __has_feature(x) 0
#endif
#if !defined(__has_warning)
# define __has_warning(x) 0
#endif

#if __has_include(<swift/objc-prologue.h>)
# include <swift/objc-prologue.h>
#endif

#pragma clang diagnostic ignored "-Wauto-import"
#if defined(__OBJC__)
#include <Foundation/Foundation.h>
#endif
#if defined(__cplusplus)
#include <cstdint>
#include <cstddef>
#include <cstdbool>
#include <cstring>
#include <stdlib.h>
#include <new>
#include <type_traits>
#else
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#endif
#if defined(__cplusplus)
#if defined(__arm64e__) && __has_include(<ptrauth.h>)
# include <ptrauth.h>
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-macro-identifier"
# ifndef __ptrauth_swift_value_witness_function_pointer
#  define __ptrauth_swift_value_witness_function_pointer(x)
# endif
# ifndef __ptrauth_swift_class_method_pointer
#  define __ptrauth_swift_class_method_pointer(x)
# endif
#pragma clang diagnostic pop
#endif
#endif

#if !defined(SWIFT_TYPEDEFS)
# define SWIFT_TYPEDEFS 1
# if __has_include(<uchar.h>)
#  include <uchar.h>
# elif !defined(__cplusplus)
typedef uint_least16_t char16_t;
typedef uint_least32_t char32_t;
# endif
typedef float swift_float2  __attribute__((__ext_vector_type__(2)));
typedef float swift_float3  __attribute__((__ext_vector_type__(3)));
typedef float swift_float4  __attribute__((__ext_vector_type__(4)));
typedef double swift_double2  __attribute__((__ext_vector_type__(2)));
typedef double swift_double3  __attribute__((__ext_vector_type__(3)));
typedef double swift_double4  __attribute__((__ext_vector_type__(4)));
typedef int swift_int2  __attribute__((__ext_vector_type__(2)));
typedef int swift_int3  __attribute__((__ext_vector_type__(3)));
typedef int swift_int4  __attribute__((__ext_vector_type__(4)));
typedef unsigned int swift_uint2  __attribute__((__ext_vector_type__(2)));
typedef unsigned int swift_uint3  __attribute__((__ext_vector_type__(3)));
typedef unsigned int swift_uint4  __attribute__((__ext_vector_type__(4)));
#endif

#if !defined(SWIFT_PASTE)
# define SWIFT_PASTE_HELPER(x, y) x##y
# define SWIFT_PASTE(x, y) SWIFT_PASTE_HELPER(x, y)
#endif
#if !defined(SWIFT_METATYPE)
# define SWIFT_METATYPE(X) Class
#endif
#if !defined(SWIFT_CLASS_PROPERTY)
# if __has_feature(objc_class_property)
#  define SWIFT_CLASS_PROPERTY(...) __VA_ARGS__
# else
#  define SWIFT_CLASS_PROPERTY(...) 
# endif
#endif
#if !defined(SWIFT_RUNTIME_NAME)
# if __has_attribute(objc_runtime_name)
#  define SWIFT_RUNTIME_NAME(X) __attribute__((objc_runtime_name(X)))
# else
#  define SWIFT_RUNTIME_NAME(X) 
# endif
#endif
#if !defined(SWIFT_COMPILE_NAME)
# if __has_attribute(swift_name)
#  define SWIFT_COMPILE_NAME(X) __attribute__((swift_name(X)))
# else
#  define SWIFT_COMPILE_NAME(X) 
# endif
#endif
#if !defined(SWIFT_METHOD_FAMILY)
# if __has_attribute(objc_method_family)
#  define SWIFT_METHOD_FAMILY(X) __attribute__((objc_method_family(X)))
# else
#  define SWIFT_METHOD_FAMILY(X) 
# endif
#endif
#if !defined(SWIFT_NOESCAPE)
# if __has_attribute(noescape)
#  define SWIFT_NOESCAPE __attribute__((noescape))
# else
#  define SWIFT_NOESCAPE 
# endif
#endif
#if !defined(SWIFT_RELEASES_ARGUMENT)
# if __has_attribute(ns_consumed)
#  define SWIFT_RELEASES_ARGUMENT __attribute__((ns_consumed))
# else
#  define SWIFT_RELEASES_ARGUMENT 
# endif
#endif
#if !defined(SWIFT_WARN_UNUSED_RESULT)
# if __has_attribute(warn_unused_result)
#  define SWIFT_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
# else
#  define SWIFT_WARN_UNUSED_RESULT 
# endif
#endif
#if !defined(SWIFT_NORETURN)
# if __has_attribute(noreturn)
#  define SWIFT_NORETURN __attribute__((noreturn))
# else
#  define SWIFT_NORETURN 
# endif
#endif
#if !defined(SWIFT_CLASS_EXTRA)
# define SWIFT_CLASS_EXTRA 
#endif
#if !defined(SWIFT_PROTOCOL_EXTRA)
# define SWIFT_PROTOCOL_EXTRA 
#endif
#if !defined(SWIFT_ENUM_EXTRA)
# define SWIFT_ENUM_EXTRA 
#endif
#if !defined(SWIFT_CLASS)
# if __has_attribute(objc_subclassing_restricted)
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# else
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# endif
#endif
#if !defined(SWIFT_RESILIENT_CLASS)
# if __has_attribute(objc_class_stub)
#  define SWIFT_RESILIENT_CLASS(SWIFT_NAME) SWIFT_CLASS(SWIFT_NAME) __attribute__((objc_class_stub))
#  define SWIFT_RESILIENT_CLASS_NAMED(SWIFT_NAME) __attribute__((objc_class_stub)) SWIFT_CLASS_NAMED(SWIFT_NAME)
# else
#  define SWIFT_RESILIENT_CLASS(SWIFT_NAME) SWIFT_CLASS(SWIFT_NAME)
#  define SWIFT_RESILIENT_CLASS_NAMED(SWIFT_NAME) SWIFT_CLASS_NAMED(SWIFT_NAME)
# endif
#endif
#if !defined(SWIFT_PROTOCOL)
# define SWIFT_PROTOCOL(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
# define SWIFT_PROTOCOL_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
#endif
#if !defined(SWIFT_EXTENSION)
# define SWIFT_EXTENSION(M) SWIFT_PASTE(M##_Swift_, __LINE__)
#endif
#if !defined(OBJC_DESIGNATED_INITIALIZER)
# if __has_attribute(objc_designated_initializer)
#  define OBJC_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
# else
#  define OBJC_DESIGNATED_INITIALIZER 
# endif
#endif
#if !defined(SWIFT_ENUM_ATTR)
# if __has_attribute(enum_extensibility)
#  define SWIFT_ENUM_ATTR(_extensibility) __attribute__((enum_extensibility(_extensibility)))
# else
#  define SWIFT_ENUM_ATTR(_extensibility) 
# endif
#endif
#if !defined(SWIFT_ENUM)
# define SWIFT_ENUM(_type, _name, _extensibility) enum _name : _type _name; enum SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# if __has_feature(generalized_swift_name)
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) enum _name : _type _name SWIFT_COMPILE_NAME(SWIFT_NAME); enum SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# else
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) SWIFT_ENUM(_type, _name, _extensibility)
# endif
#endif
#if !defined(SWIFT_UNAVAILABLE)
# define SWIFT_UNAVAILABLE __attribute__((unavailable))
#endif
#if !defined(SWIFT_UNAVAILABLE_MSG)
# define SWIFT_UNAVAILABLE_MSG(msg) __attribute__((unavailable(msg)))
#endif
#if !defined(SWIFT_AVAILABILITY)
# define SWIFT_AVAILABILITY(plat, ...) __attribute__((availability(plat, __VA_ARGS__)))
#endif
#if !defined(SWIFT_WEAK_IMPORT)
# define SWIFT_WEAK_IMPORT __attribute__((weak_import))
#endif
#if !defined(SWIFT_DEPRECATED)
# define SWIFT_DEPRECATED __attribute__((deprecated))
#endif
#if !defined(SWIFT_DEPRECATED_MSG)
# define SWIFT_DEPRECATED_MSG(...) __attribute__((deprecated(__VA_ARGS__)))
#endif
#if !defined(SWIFT_DEPRECATED_OBJC)
# if __has_feature(attribute_diagnose_if_objc)
#  define SWIFT_DEPRECATED_OBJC(Msg) __attribute__((diagnose_if(1, Msg, "warning")))
# else
#  define SWIFT_DEPRECATED_OBJC(Msg) SWIFT_DEPRECATED_MSG(Msg)
# endif
#endif
#if defined(__OBJC__)
#if !defined(IBSegueAction)
# define IBSegueAction 
#endif
#endif
#if !defined(SWIFT_EXTERN)
# if defined(__cplusplus)
#  define SWIFT_EXTERN extern "C"
# else
#  define SWIFT_EXTERN extern
# endif
#endif
#if !defined(SWIFT_CALL)
# define SWIFT_CALL __attribute__((swiftcall))
#endif
#if !defined(SWIFT_INDIRECT_RESULT)
# define SWIFT_INDIRECT_RESULT __attribute__((swift_indirect_result))
#endif
#if !defined(SWIFT_CONTEXT)
# define SWIFT_CONTEXT __attribute__((swift_context))
#endif
#if !defined(SWIFT_ERROR_RESULT)
# define SWIFT_ERROR_RESULT __attribute__((swift_error_result))
#endif
#if defined(__cplusplus)
# define SWIFT_NOEXCEPT noexcept
#else
# define SWIFT_NOEXCEPT 
#endif
#if !defined(SWIFT_C_INLINE_THUNK)
# if __has_attribute(always_inline)
# if __has_attribute(nodebug)
#  define SWIFT_C_INLINE_THUNK inline __attribute__((always_inline)) __attribute__((nodebug))
# else
#  define SWIFT_C_INLINE_THUNK inline __attribute__((always_inline))
# endif
# else
#  define SWIFT_C_INLINE_THUNK inline
# endif
#endif
#if defined(_WIN32)
#if !defined(SWIFT_IMPORT_STDLIB_SYMBOL)
# define SWIFT_IMPORT_STDLIB_SYMBOL __declspec(dllimport)
#endif
#else
#if !defined(SWIFT_IMPORT_STDLIB_SYMBOL)
# define SWIFT_IMPORT_STDLIB_SYMBOL 
#endif
#endif
#if defined(__OBJC__)
#if __has_feature(objc_modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import CoreFoundation;
@import Foundation;
@import ObjectiveC;
@import UIKit;
#endif

#endif
#pragma clang diagnostic ignored "-Wproperty-attribute-mismatch"
#pragma clang diagnostic ignored "-Wduplicate-method-arg"
#if __has_warning("-Wpragma-clang-attribute")
# pragma clang diagnostic ignored "-Wpragma-clang-attribute"
#endif
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wnullability"
#pragma clang diagnostic ignored "-Wdollar-in-identifier-extension"

#if __has_attribute(external_source_symbol)
# pragma push_macro("any")
# undef any
# pragma clang attribute push(__attribute__((external_source_symbol(language="Swift", defined_in="AppBoxSDK",generated_declaration))), apply_to=any(function,enum,objc_interface,objc_category,objc_protocol))
# pragma pop_macro("any")
#endif

#if defined(__OBJC__)
@protocol AppBoxProtocol;

/// AppBox SDK Clas
SWIFT_CLASS("_TtC9AppBoxSDK6AppBox")
@interface AppBox : NSObject
/// AppBoxProtocol 접근 생성자
SWIFT_CLASS_PROPERTY(@property (nonatomic, class, readonly, strong) id <AppBoxProtocol> _Nonnull shared;)
+ (id <AppBoxProtocol> _Nonnull)shared SWIFT_WARN_UNUSED_RESULT;
- (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
@end

@class NSString;

/// <h1>AppBoxIntro</h1>
/// <code>AppBoxSDK</code>에서 사용되는 Model로 인트로항목을 정의하는데 사용됩니다.
SWIFT_CLASS("_TtC9AppBoxSDK11AppBoxIntro")
@interface AppBoxIntro : NSObject
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>imageUrl</code>: 인트로에 사용할 이미지의 URL 문자열입니다.
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic, readonly, copy) NSString * _Nonnull imageUrl;
/// <h1>초기화 메서드</h1>
/// <code>AppBoxIntro</code> 객체를 초기화합니다. 인트로 이미지 URL이 올바른 값인지 확인 후 객체를 생성합니다.
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
///  if let intro = AppBoxIntro(imageUrl: "https://example.com/image.jpg") {
///      print("Intro image URL: \(intro.imageUrl)")
///  } else {
///      print("Failed to initialize AppBoxIntro with empty URL.")
///  }
///
/// \endcode\param imageUrl 인트로 이미지의 URL 문자열입니다.
///
///
/// returns:
/// 유효한 URL이 제공되면 객체를 반환하고, 그렇지 않으면 <code>nil</code>을 반환합니다.
- (nullable instancetype)initWithImageUrl:(NSString * _Nonnull)imageUrl OBJC_DESIGNATED_INITIALIZER;
- (nonnull instancetype)init SWIFT_UNAVAILABLE;
+ (nonnull instancetype)new SWIFT_UNAVAILABLE_MSG("-init is unavailable");
@end

@class AppBoxWebConfig;
@class UIViewController;

/// <h1>AppBoxProtocol</h1>
/// <code>AppBoxSDK</code>에서 사용되는 프로토콜로, SDK 초기화 및 다양한 설정을 제공합니다.
SWIFT_PROTOCOL("_TtP9AppBoxSDK14AppBoxProtocol_")
@protocol AppBoxProtocol
/// <h1>SDK 초기화</h1>
/// SDK를 초기화합니다. 초기화 시 기본 URL, 웹 설정, 디버그 모드를 설정합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>baseUrl</code>: 기본 URL
///   </li>
///   <li>
///     <code>webConfig</code>: 웹 설정을 위한 <code>AppBoxWebConfig</code> 객체 (옵션)
///     <ul>
///       <li>
///         default:
///         \code
///         javaScriptEnabled = true
///         javaScriptCanOpenWindowsAutomatically = true
///         allowsInlineMediaPlayback = true
///         allowsAirPlayForMediaPlayback = true
///         allowsPictureInPictureMediaPlayback = true
///         mediaTypesRequiringUserActionForPlayback = [.audio]
///
///         \endcode</li>
///     </ul>
///   </li>
///   <li>
///     <code>debugMode</code>: 디버그 모드 활성화 여부 (옵션)
///     <ul>
///       <li>
///         default: false
///       </li>
///     </ul>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// let appBoxWebConfig = AppBoxWebConfig()
/// let wkWebViewConfig = WKWebViewConfiguration()
///
/// if #available(iOS 14.0, *) {
///     wkWebViewConfig.defaultWebpagePreferences.allowsContentJavaScript = true
/// } else {
///     wkWebViewConfig.preferences.javaScriptEnabled = true
/// }
/// appBoxWebConfig.wKWebViewConfiguration = wkWebViewConfig
///
/// AppBox.shared.initSDK(baseUrl: "https://example.com", webConfig: appBoxWebConfig, debugMode: true)
///
/// \endcode
- (void)initSDKWithBaseUrl:(NSString * _Null_unspecified)baseUrl webConfig:(AppBoxWebConfig * _Nonnull)webConfig debugMode:(BOOL)debugMode SWIFT_METHOD_FAMILY(none);
/// <h1>SDK 초기화</h1>
/// SDK를 초기화합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>baseUrl</code>: 기본 URL
///   </li>
///   <li>
///     <code>webConfig</code>: 웹 설정을 위한 <code>AppBoxWebConfig</code> 객체 (옵션)
///     <ul>
///       <li>
///         default:
///         \code
///         javaScriptEnabled = true
///         javaScriptCanOpenWindowsAutomatically = true
///         allowsInlineMediaPlayback = true
///         allowsAirPlayForMediaPlayback = true
///         allowsPictureInPictureMediaPlayback = true
///         mediaTypesRequiringUserActionForPlayback = [.audio]
///
///         \endcode</li>
///     </ul>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// let appBoxWebConfig = AppBoxWebConfig()
/// let wkWebViewConfig = WKWebViewConfiguration()
///
/// if #available(iOS 14.0, *) {
///     wkWebViewConfig.defaultWebpagePreferences.allowsContentJavaScript = true
/// } else {
///     wkWebViewConfig.preferences.javaScriptEnabled = true
/// }
/// appBoxWebConfig.wKWebViewConfiguration = wkWebViewConfig
///
/// AppBox.shared.initSDK(baseUrl: "https://example.com", webConfig: appBoxWebConfig)
///
/// \endcode
- (void)initSDKWithBaseUrl:(NSString * _Null_unspecified)baseUrl webConfig:(AppBoxWebConfig * _Nonnull)webConfig SWIFT_METHOD_FAMILY(none);
/// <h1>SDK 초기화</h1>
/// SDK를 초기화합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>baseUrl</code>: 기본 URL
///   </li>
///   <li>
///     <code>debugMode</code>: 디버그 모드 활성화 여부 (옵션)
///     <ul>
///       <li>
///         default: false
///       </li>
///     </ul>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.initSDK(baseUrl: "https://example.com" debugMode: true)
///
/// \endcode
- (void)initSDKWithBaseUrl:(NSString * _Null_unspecified)baseUrl debugMode:(BOOL)debugMode SWIFT_METHOD_FAMILY(none);
/// <h1>SDK 초기화</h1>
/// SDK를 초기화합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>baseUrl</code>: 기본 URL
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.initSDK(baseUrl: "https://example.com")
///
/// \endcode
- (void)initSDKWithBaseUrl:(NSString * _Null_unspecified)baseUrl SWIFT_METHOD_FAMILY(none);
/// <h1>SDK 실행</h1>
/// SDK를 초기화 후 SDK에 화면을 실행할 때 호출합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>vc</code>: 앱이 시작될 <code>UIViewController</code>
///   </li>
///   <li>
///     <code>completion</code>: 시작 완료 후 호출될 클로저 (옵션)
///     <ul>
///       <li>
///         <code>Bool</code>: 성공 여부
///       </li>
///       <li>
///         <code>Error?</code>: 에러 객체 (옵션)
///       </li>
///     </ul>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.start(from: self) { isSuccess, error in
///    if isSuccess {
///        // 실행 성공 처리
///        print("AppBox:: SDK 실행 성공")
///    } else {
///        // 실행 실패 처리
///        if let error = error {
///            print("error : \(error.localizedDescription)")
///        } else {
///            print("error : unkown Error")
///        }
///    }
/// }
///
/// \endcode
- (void)startFrom:(UIViewController * _Nonnull)vc completion:(void (^ _Nullable)(BOOL, NSError * _Nullable))completion;
/// <h1>SDK 실행</h1>
/// SDK를 초기화 후 SDK에 화면을 실행할 때 호출합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>vc</code>: 앱이 시작될 <code>UIViewController</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.start(from: self)
///
/// \endcode
- (void)startFrom:(UIViewController * _Nonnull)vc;
/// <h1>푸시 토큰 설정</h1>
/// 푸시 토큰을 저장합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>token</code>: 푸시토큰
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.setPushToken("푸시 토큰 값")
///
/// \endcode
- (void)setPushToken:(NSString * _Nullable)token;
/// <h1>인트로 설정</h1>
/// 최초 앱 설치 후 AppBox SDK를 실행 시 인트로 화면이 노출됩니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>items</code>: 인트로 항목 배열 (<code>AppBoxIntro</code> 객체의 배열)
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// if let appBoxIntroItem1 = AppBoxIntro(imageUrl: "https://www.example.com/example1.png"),
///   let appBoxIntroItem2 = AppBoxIntro(imageUrl: "https://www.example.com/example2.png") {
///    let items = [
///        appBoxIntroItem1,
///        appBoxIntroItem2
///    ]
///    AppBox.shared.setIntro(items)
/// }
///
/// \endcode
- (void)setIntro:(NSArray<AppBoxIntro *> * _Nonnull)items;
/// <h1>당겨서 새로고침 설정</h1>
/// 당겨서 새로고침 기능의 사용 여부를 설정합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>used</code>: 당겨서 새로고침 기능 활성화 여부
///     <ul>
///       <li>
///         default: false
///       </li>
///     </ul>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// <h2>Example</h2>
/// \code
/// AppBox.shared.setPullDownRefresh(
///    used: true
/// )
///
/// \endcode
- (void)setPullDownRefreshWithUsed:(BOOL)used;
/// <h1>AppBoxPushSDK</h1>
/// AppBoxPushSDK 내부에서 사용될 함수 정의
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
/// \code
///
///
/// \endcode
- (void)pushMoveStart;
- (void)pushMoveSetUrlWithUrl:(NSString * _Nonnull)url;
@end

@class WKWebViewConfiguration;
@class NSCoder;

/// <h1>AppBoxWebConfig</h1>
/// <code>AppBoxSDK</code>에서 Web설정을 설정하기 위해 제공되는 객체
SWIFT_CLASS("_TtC9AppBoxSDK15AppBoxWebConfig")
@interface AppBoxWebConfig : NSObject <NSSecureCoding>
/// <h1>WKWebView 구성</h1>
/// <code>WKWebView</code>의 설정을 관리하는 <code>WKWebViewConfiguration</code> 객체입니다.
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic, strong) WKWebViewConfiguration * _Nullable wKWebViewConfiguration;
/// <h1>뒤로가기/앞으로가기 탐색 제스처 활성화 여부</h1>
/// 뒤로가기 및 앞으로가기 탐색 제스처(스와이프)를 사용할 수 있도록 설정합니다.
/// <ul>
///   <li>
///     Default: <code>true</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL allowsBackForwardNavigationGestures;
/// <h1>스크롤 가능한 콘텐츠 크기</h1>
/// 스크롤 가능한 콘텐츠의 크기를 설정합니다. 콘텐츠가 화면보다 클 때 스크롤이 활성화됩니다.
/// <ul>
///   <li>
///     Default: <code>CGSize.zero</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) CGSize scrollContentSize;
/// <h1>스크롤 콘텐츠의 현재 위치</h1>
/// 콘텐츠 뷰의 좌상단 기준으로 현재 스크롤 위치를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>CGPoint.zero</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) CGPoint scrollContentOffset;
/// <h1>스크롤 콘텐츠 여백</h1>
/// 스크롤 콘텐츠 주변에 추가 공간을 설정합니다.
/// <ul>
///   <li>
///     Default: <code>UIEdgeInsets.zero</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) UIEdgeInsets scrollContentInset;
/// <h1>스크롤 활성화 여부</h1>
/// 스크롤 가능 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>true</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL isScrollEnabled;
/// <h1>스크롤 바운스 설정</h1>
/// 스크롤 뷰가 콘텐츠 경계를 넘어서 스크롤할 때 반응하는지 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>true</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL scrollBounces;
/// <h1>수직 방향 바운스 항상 활성화 여부</h1>
/// 콘텐츠 높이가 스크롤 뷰의 높이보다 작을 때도 수직 방향으로 바운스할지 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>false</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL scrollAlwaysBounceVertical;
/// <h1>수평 방향 바운스 항상 활성화 여부</h1>
/// 콘텐츠 너비가 스크롤 뷰의 너비보다 작을 때도 수평 방향으로 바운스할지 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>false</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL scrollAlwaysBounceHorizontal;
/// <h1>수평 스크롤 인디케이터 표시 여부</h1>
/// 수평 스크롤 인디케이터의 표시 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>false</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL showsHorizontalScrollIndicator;
/// <h1>수직 스크롤 인디케이터 표시 여부</h1>
/// 수직 스크롤 인디케이터의 표시 여부를 설정합니다.
/// <ul>
///   <li>
///     Default: <code>false</code>
///   </li>
/// </ul>
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
@property (nonatomic) BOOL showsVerticalScrollIndicator;
/// <h1>NSSecureCoding 지원 여부</h1>
/// 객체가 <code>NSSecureCoding</code>을 지원하는지 나타냅니다.
/// <h2>Author</h2>
/// <ul>
///   <li>
///     ss.moon
///   </li>
/// </ul>
SWIFT_CLASS_PROPERTY(@property (nonatomic, class, readonly) BOOL supportsSecureCoding;)
+ (BOOL)supportsSecureCoding SWIFT_WARN_UNUSED_RESULT;
/// <h1>기본 초기화</h1>
/// <code>AppBoxWebConfig</code>의 기본 속성값으로 객체를 초기화합니다.
- (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
/// <h1>NSCoder를 통한 초기화</h1>
/// 저장된 상태를 사용해 <code>AppBoxWebConfig</code> 객체를 초기화합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>coder</code>: 객체를 디코딩하는 데 사용되는 <code>NSCoder</code>
///   </li>
/// </ul>
- (nullable instancetype)initWithCoder:(NSCoder * _Nonnull)coder OBJC_DESIGNATED_INITIALIZER;
/// <h1>NSCoder를 통한 상태 저장</h1>
/// 객체 상태를 저장합니다.
/// <h2>Parameters</h2>
/// <ul>
///   <li>
///     <code>coder</code>: 객체를 인코딩하는 데 사용되는 <code>NSCoder</code>
///   </li>
/// </ul>
- (void)encodeWithCoder:(NSCoder * _Nonnull)coder;
@end














#endif
#if __has_attribute(external_source_symbol)
# pragma clang attribute pop
#endif
#if defined(__cplusplus)
#endif
#pragma clang diagnostic pop
#endif

#else
#error unsupported Swift architecture
#endif
