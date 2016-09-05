/**
 *  Copyright 2014-2016 CyberVision, Inc.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#import "ViewController.h"
#import "KaaManager.h"
#import "User.h"

#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <Fabric/Fabric.h>
#import <TwitterKit/TwitterKit.h>
#import <Google/SignIn.h>

@import Kaa;

@interface ViewController () <FBSDKLoginButtonDelegate, GIDSignInUIDelegate, GIDSignInDelegate, UserAttachDelegate, DetachEndpointFromUserDelegate>

@property (weak, nonatomic) IBOutlet UIStackView *socialButtonsStackView;

@property (weak, nonatomic) IBOutlet FBSDKLoginButton *fbLoginButton;
@property (weak, nonatomic) IBOutlet TWTRLogInButton *twtrLogInButton;
@property (weak, nonatomic) IBOutlet GIDSignInButton *googleLogInButton; 
@property (weak, nonatomic) IBOutlet UIButton *logOutButton;

@property (nonatomic, strong) KaaManager *kaaManager;
@property (nonatomic, strong) User *user;
@property (nonatomic) AuthorizedNetwork authorizedNetwork;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.logOutButton.hidden = YES;
    self.googleLogInButton.colorScheme = kGIDSignInButtonColorSchemeDark;
    
    self.fbLoginButton.delegate = self;
    [GIDSignIn sharedInstance].uiDelegate = self;
    [GIDSignIn sharedInstance].delegate = self;
    
    self.twtrLogInButton.loginMethods = TWTRLoginMethodAll;
    self.twtrLogInButton.logInCompletion = ^(TWTRSession *session, NSError *error) {
        if (session) {
            NSLog(@"Signed in as %@", [session userName]);
            self.user = [[User alloc] initWithUserId:session.userID token:session.authToken authorizedNetwork:AuthorizedNetworkTwitter];
            [self loggedInWithNetwork:AuthorizedNetworkTwitter];
        } else {
            NSLog(@"error: %@", [error localizedDescription]);
        }
    };
    self.kaaManager = [KaaManager sharedInstance];
}

- (void)loggedInWithNetwork:(AuthorizedNetwork)network {
    switch (network) {
        case AuthorizedNetworkFacebook:
            self.twtrLogInButton.hidden = YES;
            self.googleLogInButton.hidden = YES;
            break;
            
        case AuthorizedNetworkTwitter:
        case AuthorizedNetworkGoogle:
            self.fbLoginButton.hidden = YES;
            self.twtrLogInButton.hidden = YES;
            self.googleLogInButton.hidden = YES;
            self.logOutButton.hidden = NO;
            break;
            
        default:
            break;
    }
}

#pragma mark - FBSDKLoginButtonDelegate

- (void)loginButton:(FBSDKLoginButton *)loginButton didCompleteWithResult:(FBSDKLoginManagerLoginResult *)result error:(NSError *)error {
    if (result.token) {
        NSLog(@"Signed in as user with id %@", result.token.userID);
        self.twtrLogInButton.hidden = YES;
        self.googleLogInButton.hidden = YES;
        self.user = [[User alloc] initWithUserId:result.token.userID token:result.token.tokenString authorizedNetwork:AuthorizedNetworkFacebook];
        [self.kaaManager attachUser:self.user delegate:self];
    }
}

- (void)loginButtonDidLogOut:(FBSDKLoginButton *)loginButton {
    [self.kaaManager detachEndpoitWithDelegate:self];
    self.twtrLogInButton.hidden = NO;
    self.googleLogInButton.hidden = NO;
}

#pragma mark - GIDSignInDelegate

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    [self loggedInWithNetwork:AuthorizedNetworkGoogle];
    NSLog(@"Signed in as %@", user.profile.name);
    self.user = [[User alloc] initWithUserId:user.userID token:user.authentication.accessToken authorizedNetwork:AuthorizedNetworkGoogle];
    [self.kaaManager attachUser:self.user delegate:self];
}

#pragma mark - UserAttachDelegate

- (void)onAttachResult:(UserAttachResponse *)response {
    switch (response.result) {
        case SYNC_RESPONSE_RESULT_TYPE_SUCCESS:
            NSLog(@"User attach result: success.");
            break;
            
        case SYNC_RESPONSE_RESULT_TYPE_FAILURE:
            NSLog(@"User attach result type: failure.");
            break;
            
        default:
            break;
    }
    if (response.errorCode.branch == KAA_UNION_USER_ATTACH_ERROR_CODE_OR_NULL_BRANCH_0) {
        NSLog(@"Error code: %@, error reason: %@", response.errorCode.data, response.errorReason.data);
    }
}

- (void)onDetachedEndpointWithAccessToken:(NSString *)endpointAccessToken {
    NSLog(@"Endpoint with access token %@ was sucessfully detached.", endpointAccessToken);
}

#pragma mark - Actions

- (IBAction)logOutBtnPressed:(id)sender {
    if (self.user.network == AuthorizedNetworkTwitter) {
        TWTRSessionStore *store = [[Twitter sharedInstance] sessionStore];
        NSString *userID = store.session.userID;
        
        [store logOutUserID:userID];
    } else {
        [[GIDSignIn sharedInstance] signOut];
    }
    
    [self.kaaManager detachEndpoitWithDelegate:self];
    
    self.fbLoginButton.hidden = NO;
    self.twtrLogInButton.hidden = NO;
    self.googleLogInButton.hidden = NO;
    self.logOutButton.hidden = YES;
}

@end
