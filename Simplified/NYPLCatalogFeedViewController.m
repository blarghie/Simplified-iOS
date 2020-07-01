#import "NYPLCatalogGroupedFeed.h"
#import "NYPLCatalogGroupedFeedViewController.h"
#import "NYPLCatalogUngroupedFeed.h"
#import "NYPLCatalogUngroupedFeedViewController.h"
#import "NYPLConfiguration.h"
#import "NYPLOPDS.h"
#import "NYPLXML.h"
#import "SimplyE-Swift.h"
#import "NYPLCatalogFeedViewController.h"

@implementation NYPLCatalogFeedViewController

- (instancetype)initWithURL:(NSURL *const)URL
{
  self = [super initWithURL:URL
                    handler:^UIViewController *(NYPLRemoteViewController *remoteVC,
                                                NSData *data,
                                                NSURLResponse *response) {

    return [NYPLCatalogFeedViewController makeWithRemoteVC:remoteVC
                                                      data:data
                                               urlResponse:response];
  }];
  
  return self;
}

+ (UIViewController*)makeWithRemoteVC:(NYPLRemoteViewController *)remoteVC
                                 data:(NSData*)data
                          urlResponse:(NSURLResponse*)response
{
  if (![response.MIMEType isEqualToString:@"application/atom+xml"]) {
    NYPLLOG(@"Did not recieve XML atom feed, cannot initialize");
    [NYPLErrorLogger
     logCatalogInitErrorWithCode:NYPLErrorCodeInvalidResponseMimeType];
    return nil;
  }

  NYPLXML *const XML = [NYPLXML XMLWithData:data];
  if(!XML) {
    NYPLLOG(@"Cannot initialize due to invalid XML.");
    [NYPLErrorLogger
     logCatalogInitErrorWithCode:NYPLErrorCodeInvalidXML];
    return nil;
  }

  NYPLOPDSFeed *const feed = [[NYPLOPDSFeed alloc] initWithXML:XML];
  if(!feed) {
    NYPLLOG(@"Cannot initialize due to XML not representing an OPDS feed.");
    [NYPLErrorLogger
     logCatalogInitErrorWithCode:NYPLErrorCodeOpdsFeedParseFail];
    return nil;
  }

  switch(feed.type) {
    case NYPLOPDSFeedTypeAcquisitionGrouped:
      return [[NYPLCatalogGroupedFeedViewController alloc]
              initWithGroupedFeed:[[NYPLCatalogGroupedFeed alloc]
                                   initWithOPDSFeed:feed]
              remoteViewController:remoteVC];
    case NYPLOPDSFeedTypeAcquisitionUngrouped:
      return [[NYPLCatalogUngroupedFeedViewController alloc]
              initWithUngroupedFeed:[[NYPLCatalogUngroupedFeed alloc]
                                     initWithOPDSFeed:feed]
              remoteViewController:remoteVC];
    case NYPLOPDSFeedTypeInvalid:
      NYPLLOG(@"Cannot initialize due to invalid feed.");
      [NYPLErrorLogger logCatalogInitErrorWithCode:NYPLErrorCodeInvalidFeedType];
      return nil;
    case NYPLOPDSFeedTypeNavigation: {
      return [NYPLCatalogFeedViewController navigationFeedWithData:XML
                                                          remoteVC:remoteVC];
    }
  }
}

// Only NavigationType Feed currently supported in the app is for two
// "Instant Classic" feeds presented based on user's age.
+ (UIViewController *)navigationFeedWithData:(NYPLXML *)data remoteVC:(NYPLRemoteViewController *)vc
{
  NYPLXML *gatedXML = [data firstChildWithName:@"gate"];
  if (!gatedXML) {
    NYPLLOG(@"Cannot initialize due to lack of support for navigation feeds.");
    [NYPLErrorLogger logErrorWithCode:NYPLErrorCodeNoAgeGateElement
                              context:NSStringFromClass([self class])
                              message:@"Data received from Server lacks `gate` element for age-check."
                             metadata:nil];
    return nil;
  }
  
  [[AgeCheck shared] verifyCurrentAccountAgeRequirement:^(BOOL ageAboveLimit) {
    NSURL *url;
    if (ageAboveLimit) {
      url = [NSURL URLWithString:gatedXML.attributes[@"restriction-met"]];
    } else {
      url = [NSURL URLWithString:gatedXML.attributes[@"restriction-not-met"]];
    }
    [vc setURL:url];
    [vc load];
  }];
  
  return [[UIViewController alloc] init];
}

#pragma mark UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  NYPLSettings *settings = [NYPLSettings sharedSettings];
  
  if (settings.userHasSeenWelcomeScreen == YES) {
    [self load];
  }

  [[NYPLBookRegistry sharedRegistry] justLoad];
  UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
  if (applicationState == UIApplicationStateActive) {
    [self syncBookRegistryForNewFeed];
  } else {
    /// Performs with a delay because on a fresh launch, the application state takes
    /// a moment to accurately update.
    [[NSNotificationCenter defaultCenter] postNotificationName:NSNotification.NYPLSyncBegan object:nil];
    [self performSelector:@selector(syncBookRegistryForNewFeed) withObject:self afterDelay:2.0];
  }
}

- (void) reloadCatalogue {
  [self load];
}

- (void)viewWillAppear:(__attribute__((unused)) BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO];
}

/// Only sync the book registry for a new feed if the app is in the active state.
- (void)syncBookRegistryForNewFeed
{
  UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
  if (applicationState == UIApplicationStateActive) {
    __weak __auto_type wSelf = self;
    [[NYPLBookRegistry sharedRegistry] syncWithCompletionHandler:^(BOOL success) {
      if (success) {
        [[NYPLBookRegistry sharedRegistry] save];
      } else {
        [NYPLErrorLogger logErrorWithCode:NYPLErrorCodeRegistrySyncFailure
                                  context:NSStringFromClass([wSelf class])
                                  message:@"Book registry sync failed"
                                 metadata:@{@"Catalog feed URL": wSelf.URL ?: @"none"}];
      }
    }];
  }
}

@end
