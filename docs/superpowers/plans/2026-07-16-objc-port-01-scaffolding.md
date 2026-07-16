# Objective-C Port — Plan 1: Project Scaffolding & Core/Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a working, independently-buildable Objective-C Xcode project (`Rogers-Event Assignment - ObjC/`) — its own `.xcodeproj` generated via `xcodegen`, a launchable (blank-screen) app target, an XCTest target that runs against it, the Core Data schema file, the Secrets mechanism, and the first two real, fully-tested `Core/Support` utilities (`RGClock`, `NSString+RGHashing`). This is Plan 1 of a multi-plan port (see `docs/superpowers/specs/2026-07-16-objc-coredata-port-design.md`); subsequent plans build Core/Networking, Core/Cache, Core/Location, Core/Persistence, Domain, Repository, and Features on top of this foundation.

**Architecture:** New sibling folder to the Swift project, fully independent Xcode project generated from a `project.yml` (not hand-written `pbxproj`). Two targets: the app and an XCTest bundle hosted inside it (`TEST_HOST`), the Objective-C equivalent of `@testable import`. Info.plist is a static file mirroring the Swift app's permissions/background-mode declarations exactly.

**Tech Stack:** Objective-C, UIKit, Core Data, XCTest, CommonCrypto, `xcodegen` (Homebrew, dev-tool only).

---

## Spec requirements covered by this plan

From `docs/superpowers/specs/2026-07-16-objc-coredata-port-design.md`: "Project setup" (folder, `xcodegen`, targets, `Secrets.h`), "Core Data schema" (the `.xcdatamodeld` file), and the `RGClock`/`NSString+RGHashing` portion of "Core/Support" in the file mapping table. Everything else in the spec (Networking, Cache, Location, Persistence logic, Background, Domain, Repository, Features, App wiring, full docs) is out of scope for this plan and covered by later plans.

## Task 1: Folder structure, `.gitignore`, and `Secrets.h.example`

**Files:**
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/Secrets.h.example`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/.gitkeep`
- Modify: `.gitignore` (repo root)

- [ ] **Step 1: Create the directory tree**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Networking"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Cache"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Location"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Persistence"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Background"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Domain"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Repository"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Features/Home"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Features/EventDetail"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Features/Shared"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests"
mkdir -p "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCUITests"
```
Expected: no output, exit code 0. Empty directories don't survive in git, so later steps that add real files into each will make them appear.

- [ ] **Step 2: Write `Secrets.h.example`**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/Secrets.h.example`:

```objc
// Copy this file to Secrets.h (which is gitignored) and fill in a real
// Ticketmaster Discovery API key. Never commit the real key.
//
//   cp "Secrets.h.example" "Secrets.h"

#import <Foundation/Foundation.h>

static NSString * const kRGTicketmasterAPIKey = @"YOUR_TICKETMASTER_API_KEY";
```

- [ ] **Step 3: Extend `.gitignore`**

In `.gitignore` (repo root), find the line `**/Secrets.swift` and add a new line directly after it:

```
**/Secrets.h
```

The full secrets section should now read:
```
# Secrets — never commit the real API key
**/Secrets.swift
**/Secrets.h
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/Secrets.h.example" .gitignore
git commit -m "$(cat <<'EOF'
Scaffold Objective-C port folder structure and Secrets mechanism

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds (empty directories aren't tracked by git yet, only the two real files).

## Task 2: `Info.plist`

**Files:**
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Info.plist`

- [ ] **Step 1: Write the Info.plist**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneConfigurationName</key>
					<string>Default Configuration</string>
					<key>UISceneDelegateClassName</key>
					<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
				</dict>
			</array>
		</dict>
	</dict>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Local Events Explorer uses your location to show how far away events are and sort them by proximity. Your location is never sent anywhere except to calculate this on your device.</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
	</array>
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>ca.cybermedia.Rogers-Event-Assignment-ObjC.refresh</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Info.plist"
git commit -m "$(cat <<'EOF'
Add Info.plist for Objective-C port, mirroring Swift app permissions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 3: Minimal app shell (`main.m`, `AppDelegate`, `SceneDelegate`)

These are the standard UIKit app-lifecycle entry points — the Objective-C
equivalent of the Swift app's `@main App` struct. The root view controller is
a blank placeholder; a later plan (Features + App wiring) replaces it with
`RGHomeViewController`.

**Files:**
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/main.m`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/AppDelegate.h`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/AppDelegate.m`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/SceneDelegate.h`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/SceneDelegate.m`

- [ ] **Step 1: Write `SceneDelegate.h`**

```objc
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic, nullable) UIWindow *window;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: Write `SceneDelegate.m`**

```objc
#import "SceneDelegate.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                  options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];

    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];
}

@end
```

- [ ] **Step 3: Write `AppDelegate.h`**

```objc
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 4: Write `AppDelegate.m`**

```objc
#import "AppDelegate.h"
#import "SceneDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration =
        [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                        sessionRole:connectingSceneSession.role];
    configuration.delegateClass = [SceneDelegate class];
    return configuration;
}

@end
```

- [ ] **Step 5: Write `main.m`**

```objc
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString *appDelegateClassName;
    @autoreleasepool {
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
```

- [ ] **Step 6: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/main.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/AppDelegate.h" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/AppDelegate.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/SceneDelegate.h" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/App/SceneDelegate.m"
git commit -m "$(cat <<'EOF'
Add minimal UIKit app shell for Objective-C port

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 4: `project.yml` and first `xcodegen generate`

**Files:**
- Create: `Rogers-Event Assignment - ObjC/project.yml`

- [ ] **Step 1: Write `project.yml`**

Create `Rogers-Event Assignment - ObjC/project.yml`:

```yaml
name: Rogers-Event Assignment - ObjC
options:
  bundleIdPrefix: ca.cybermedia
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
configs:
  Debug: debug
  Release: release
targets:
  Rogers-Event Assignment - ObjC:
    type: application
    platform: iOS
    sources:
      - path: Rogers-Event Assignment - ObjC
    info:
      path: Rogers-Event Assignment - ObjC/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ca.cybermedia.Rogers-Event-Assignment-ObjC
        GENERATE_INFOPLIST_FILE: NO
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CLANG_ENABLE_OBJC_ARC: YES
        ENABLE_TESTABILITY: YES
  Rogers-Event Assignment - ObjCTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Rogers-Event Assignment - ObjCTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ca.cybermedia.Rogers-Event-Assignment-ObjCTests
        CLANG_ENABLE_OBJC_ARC: YES
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Rogers-Event Assignment - ObjC.app/Rogers-Event Assignment - ObjC"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: Rogers-Event Assignment - ObjC
schemes:
  Rogers-Event Assignment - ObjC:
    build:
      targets:
        Rogers-Event Assignment - ObjC: all
        Rogers-Event Assignment - ObjCTests: [test]
    test:
      targets:
        - Rogers-Event Assignment - ObjCTests
    run:
      config: Debug
```

- [ ] **Step 2: Generate the Xcode project**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodegen generate
```
Expected: `Generated project at Rogers-Event Assignment - ObjC.xcodeproj` with no errors. A new `Rogers-Event Assignment - ObjC.xcodeproj` directory appears.

- [ ] **Step 3: Verify the app target builds**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodebuild -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. If it fails on a missing `AppIcon` asset catalog reference, remove the `ASSETCATALOG_COMPILER_APPICON_NAME` setting line from `project.yml`, rerun `xcodegen generate`, and rebuild.

- [ ] **Step 4: Add `.xcodeproj` to git, and gitignore its user-state files**

The Swift project's root `.gitignore` already covers `xcuserdata/`, so no changes needed there.

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/project.yml" "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC.xcodeproj"
git commit -m "$(cat <<'EOF'
Generate Objective-C port Xcode project via xcodegen

App target builds and launches to a blank screen; unit test target
is wired up with TEST_HOST to run against it. Business logic starts
in the next task.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 5: `RGClock` (TDD)

Mirrors the Swift app's `Clock` protocol — an injectable point-in-time source
so TTL-based caches and date-window logic can be tested deterministically
without real `sleep`s.

**Files:**
- Test: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/RGClockTests.m`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/RGClock.h`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/RGClock.m`

- [ ] **Step 1: Write the failing test**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/RGClockTests.m`:

```objc
#import <XCTest/XCTest.h>
#import "RGClock.h"

@interface RGClockTests : XCTestCase
@end

@implementation RGClockTests

- (void)testSystemClockNowReturnsCurrentTime {
    RGSystemClock *clock = [[RGSystemClock alloc] init];
    NSDate *before = [NSDate date];

    NSDate *now = [clock now];

    NSDate *after = [NSDate date];
    XCTAssertTrue([now compare:before] != NSOrderedAscending);
    XCTAssertTrue([now compare:after] != NSOrderedDescending);
}

- (void)testConformsToRGClockProtocol {
    RGSystemClock *clock = [[RGSystemClock alloc] init];
    XCTAssertTrue([clock conformsToProtocol:@protocol(RGClock)]);
}

@end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:"Rogers-Event Assignment - ObjCTests/RGClockTests" 2>&1 | tail -30
```
Expected: **BUILD FAILED** — `'RGClock.h' file not found` (the header doesn't exist yet). This is the correct failure: it proves the test is actually exercising code that doesn't exist.

- [ ] **Step 3: Write `RGClock.h`**

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Mirrors the Swift app's `Clock` protocol: an injectable point-in-time
/// source so TTL-based caches and date-window logic can be tested
/// deterministically instead of relying on real `sleep`s.
@protocol RGClock <NSObject>

- (NSDate *)now;

@end

@interface RGSystemClock : NSObject <RGClock>

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 4: Write `RGClock.m`**

```objc
#import "RGClock.h"

@implementation RGSystemClock

- (NSDate *)now {
    return [NSDate date];
}

@end
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:"Rogers-Event Assignment - ObjCTests/RGClockTests" 2>&1 | tail -30
```
Expected: `** TEST SUCCEEDED **`, both `testSystemClockNowReturnsCurrentTime` and `testConformsToRGClockProtocol` pass.

If `xcodebuild` reports the new files aren't part of the target: `xcodegen generate` again from `Rogers-Event Assignment - ObjC/` (xcodegen's `sources: path:` globs the folder, so newly added files need a regenerate to be picked up into the `pbxproj` file list) before rerunning the test command.

- [ ] **Step 6: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/RGClock.h" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/RGClock.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/RGClockTests.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC.xcodeproj"
git commit -m "$(cat <<'EOF'
Add RGClock protocol and RGSystemClock implementation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 6: `NSString+RGHashing` (TDD)

Mirrors the Swift app's `String.sha256Hex` — deterministic filesystem-safe
cache keys for `RGResponseCache`/`RGImageCache` (built in a later plan), using
CommonCrypto (first-party Apple framework, not a third-party dependency).

**Files:**
- Test: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/NSString_RGHashingTests.m`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/NSString+RGHashing.h`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/NSString+RGHashing.m`

- [ ] **Step 1: Write the failing test**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/NSString_RGHashingTests.m`:

```objc
#import <XCTest/XCTest.h>
#import "NSString+RGHashing.h"

@interface NSString_RGHashingTests : XCTestCase
@end

@implementation NSString_RGHashingTests

- (void)testEmptyStringHashesToKnownSHA256Value {
    XCTAssertEqualObjects(
        [@"" rg_sha256Hex],
        @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    );
}

- (void)testKnownStringHashesToKnownSHA256Value {
    XCTAssertEqualObjects(
        [@"abc" rg_sha256Hex],
        @"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
}

- (void)testSameInputProducesSameHash {
    NSString *url = @"https://example.com/image.jpg";
    XCTAssertEqualObjects([url rg_sha256Hex], [url rg_sha256Hex]);
}

- (void)testDifferentInputsProduceDifferentHashes {
    XCTAssertNotEqualObjects(
        [@"https://example.com/a.jpg" rg_sha256Hex],
        [@"https://example.com/b.jpg" rg_sha256Hex]
    );
}

- (void)testHashIsLowercaseHexOfCorrectLength {
    NSString *hash = [@"some-cache-key" rg_sha256Hex];
    XCTAssertEqual(hash.length, (NSUInteger)64);
    NSCharacterSet *hexDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    XCTAssertEqual([hash rangeOfCharacterFromSet:hexDigits.invertedSet].location, (NSUInteger)NSNotFound);
}

@end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodegen generate
xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:"Rogers-Event Assignment - ObjCTests/NSString_RGHashingTests" 2>&1 | tail -30
```
Expected: **BUILD FAILED** — `'NSString+RGHashing.h' file not found`.

- [ ] **Step 3: Write `NSString+RGHashing.h`**

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (RGHashing)

/// Deterministic filesystem-safe cache key derived from an arbitrary string
/// (typically a request or image URL). CommonCrypto is a first-party Apple
/// framework, not a third-party dependency.
- (NSString *)rg_sha256Hex;

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 4: Write `NSString+RGHashing.m`**

```objc
#import "NSString+RGHashing.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (RGHashing)

- (NSString *)rg_sha256Hex {
    const char *bytes = [self UTF8String];
    NSUInteger length = [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes, (CC_LONG)length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [hex copy];
}

@end
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:"Rogers-Event Assignment - ObjCTests/NSString_RGHashingTests" 2>&1 | tail -30
```
Expected: `** TEST SUCCEEDED **`, all 5 tests pass.

- [ ] **Step 6: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/NSString+RGHashing.h" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/Core/Support/NSString+RGHashing.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjCTests/NSString_RGHashingTests.m" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC.xcodeproj"
git commit -m "$(cat <<'EOF'
Add NSString+RGHashing category using CommonCrypto SHA-256

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 7: Core Data schema (`PersistenceModel.xcdatamodeld`)

Defines the `PersistedEvent` entity now, matching the Swift app's SwiftData
model field-for-field. The generated `RGPersistedEvent` class and its custom
convenience methods (`updateWithEvent:fetchedAt:`, `asDomainEvent`) are built
in a later plan (Core/Persistence) — this task only needs the schema to exist
and the project to still build with it present.

**Files:**
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld/.xccurrentversion`
- Create: `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld/PersistenceModel.xcdatamodel/contents`

- [ ] **Step 1: Create the model bundle directory**

Run:
```bash
mkdir -p "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld/PersistenceModel.xcdatamodel"
```

- [ ] **Step 2: Write the model contents**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld/PersistenceModel.xcdatamodel/contents`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="23788" systemVersion="24A335" minimumToolsVersion="Automatic" sourceLanguage="Objective-C" userDefinedModelVersionIdentifier="">
    <entity name="PersistedEvent" representedClassName="RGPersistedEvent" syncable="YES" codeGenerationType="class">
        <attribute name="category" optional="YES" attributeType="String"/>
        <attribute name="fetchedAt" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="identifier" attributeType="String"/>
        <attribute name="imageURLString" optional="YES" attributeType="String"/>
        <attribute name="infoURLString" optional="YES" attributeType="String"/>
        <attribute name="isBookmarked" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
        <attribute name="startDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="timeZoneIdentifier" optional="YES" attributeType="String"/>
        <attribute name="title" attributeType="String"/>
        <attribute name="venueAddress" optional="YES" attributeType="String"/>
        <attribute name="venueCity" optional="YES" attributeType="String"/>
        <attribute name="venueLatitude" optional="YES" attributeType="Double" usesScalarValueType="NO"/>
        <attribute name="venueLongitude" optional="YES" attributeType="Double" usesScalarValueType="NO"/>
        <attribute name="venueName" optional="YES" attributeType="String"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="identifier"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
    <elements>
        <element name="PersistedEvent" positionX="-63" positionY="-18" width="128" height="269"/>
    </elements>
</model>
```

Note: the attribute is named `identifier`, not `id` — `id` is a reserved keyword in Objective-C (the generic object pointer type), and Core Data's codegen would produce an invalid `- (NSString *)id;` accessor if the attribute were named `id`.

- [ ] **Step 3: Write `.xccurrentversion`**

Create `Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld/.xccurrentversion`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>_XCCurrentVersionName</key>
	<string>PersistenceModel.xcdatamodel</string>
</dict>
</plist>
```

- [ ] **Step 4: Regenerate the project and verify it still builds**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodegen generate
xcodebuild -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **`. Core Data's `codeGenerationType="class"` generates `RGPersistedEvent`'s base class into `DerivedData` automatically at build time — no manual codegen step needed, and no hand-written `RGPersistedEvent.h`/`.m` exists yet at this point (that's intentional; the next plan adds a hand-written category on top of the generated class for custom methods).

- [ ] **Step 5: Commit**

```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git add "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC/PersistenceModel.xcdatamodeld" \
        "Rogers-Event Assignment - ObjC/Rogers-Event Assignment - ObjC.xcodeproj"
git commit -m "$(cat <<'EOF'
Add Core Data schema for PersistedEvent

Field-for-field match with the Swift app's SwiftData model, except
id -> identifier (id is a reserved word in Objective-C).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

## Task 8: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the complete test suite**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment/Rogers-Event Assignment - ObjC"
xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -40
```
Expected: `** TEST SUCCEEDED **`, all 6 tests across `RGClockTests` and `NSString_RGHashingTests` pass.

- [ ] **Step 2: Confirm `Secrets.h` is not tracked**

Run:
```bash
cd "/Users/fayyazuddinsyed/Developer/Rogers-Event Assignment"
git status --short "Rogers-Event Assignment - ObjC"
```
Expected: clean (no untracked or modified files reported) — `Secrets.h` doesn't exist yet since it's only created by a developer copying `Secrets.h.example`, and everything else from this plan is already committed.

- [ ] **Step 3: Confirm the app launches in the simulator**

Run:
```bash
xcrun simctl bootstatus "iPhone 17 Pro" -b 2>&1 | tail -1
xcrun simctl install "iPhone 17 Pro" "$(find ~/Library/Developer/Xcode/DerivedData -path '*Rogers-Event Assignment - ObjC*/Build/Products/Debug-iphonesimulator/Rogers-Event Assignment - ObjC.app' -print -quit)"
xcrun simctl launch "iPhone 17 Pro" ca.cybermedia.Rogers-Event-Assignment-ObjC
sleep 3
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/objc_scaffold_check.png
```
Expected: a screenshot of a blank white/system-background screen (no crash). This confirms the app shell, Info.plist, and scene lifecycle are wired correctly end to end.

## Self-review notes

- **Spec coverage for this plan's scope:** "Project setup" ✅ (folder, xcodegen, Secrets, targets), "Core Data schema" ✅ (Task 7), `RGClock`/`NSString+RGHashing` from the file mapping table ✅ (Tasks 5–6). Everything else in the spec is explicitly out of scope and deferred to later plans (noted at the top of this document).
- **Naming consistency:** `RGClock`/`RGSystemClock` and `rg_sha256Hex` are the exact names used in every task that references them; no drift between steps.
- **`id` → `identifier` rename**: flagged inline in Task 7 since it's a deviation from the spec's field list (which said `id`) — necessary because `id` is a reserved word in Objective-C. Later plans (`RGEvent`, `RGPersistedEvent`, `RGEventStore`) must use `identifier` consistently, not `id`.

---

## Next plans in this port

1. ~~Plan 1: Project scaffolding & Core/Support~~ (this document)
2. Plan 2: Core/Networking (`RGAPIError`, `RGLoadState`, `RGRetryPolicy`, `RGTicketmasterEndpoint`, `RGNetworkService`) + Core/Cache (`RGResponseCache`, `RGImageCache`)
3. Plan 3: Core/Location + Core/Persistence (`RGCoreDataStack`, `RGPersistedEvent`, `RGEventStore`) + Core/Background
4. Plan 4: Domain (`RGEvent`, `RGVenue`, DTOs) + Repository (`RGEventsRepository`)
5. Plan 5: Features (Home, EventDetail, Shared) + App wiring (`RGAppDependencies`, real root view controller)
6. Plan 6: Docs (README, ARCHITECTURE, SEQUENCE, ENGINEERING_STANDARDS) + `.clang-format` + final polish

Each subsequent plan will be written with `writing-plans` once the prior one is
merged, per the spec's scope note.
