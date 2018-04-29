//
//  ViewController.m
//  Overlay-Graphics
//
//  Created by Sridhar on 28/02/14.
//  Copyright (c) 2014 Tokbox. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "TBExampleVideoView.h"
#import "TBExampleOverlayView.h"
#import "TBExampleVideoCapture.h"

@interface ViewController () <OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, TBExampleVideoViewDelegate, OTSubscriberKitAudioLevelDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) TBExampleVideoView *publisherVideoView;
@property (nonatomic) TBExampleVideoView *subscriberVideoView;
@end

@implementation ViewController
static double widgetHeight = 240;
static double widgetWidth = 320;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString *const kApiKey = @"";
// Replace with your generated session ID
static NSString *const kSessionId = @"";
// Replace with your generated token
static NSString *const kToken = @"";

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Step 1: As the view comes into the foreground, initialize a new instance
    // of OTSession and begin the connection process.
    self.session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}
#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    [self.session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    OTPublisherSettings *pubSettings = [[OTPublisherSettings alloc] init];
    pubSettings.name = [[UIDevice currentDevice] name];
    self.publisher = [[OTPublisher alloc]
                  initWithDelegate:self
                  settings:pubSettings];
    
    TBExampleVideoCapture* videoCapture =
    [[[TBExampleVideoCapture alloc] init] autorelease];
    [self.publisher setVideoCapture:videoCapture];
    
    self.publisherVideoView =
    [[TBExampleVideoView alloc] initWithFrame:CGRectMake(0,0,1,1)
                                     delegate:self
                                         type:OTVideoViewTypePublisher
                                  displayName:nil];
    
    // Set mirroring only if the front camera is being used.
    [self.publisherVideoView.videoView setMirroring:
     (AVCaptureDevicePositionFront == videoCapture.cameraPosition)];
    [self.publisher setVideoRender:self.publisherVideoView];
    
    OTError *error = nil;
    [self.session publish:self.publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [self.publisherVideoView setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
    [self.view addSubview:self.publisherVideoView];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [self.publisher.view removeFromSuperview];
    self.publisher = nil;
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    self.subscriber = [[OTSubscriber alloc] initWithStream:stream
                                              delegate:self];
    
    self.subscriberVideoView =
    [[TBExampleVideoView alloc] initWithFrame:CGRectMake(0,0,1,1)
                                     delegate:self
                                         type:OTVideoViewTypeSubscriber
                                  displayName:nil];
    
    [self.subscriber setVideoRender:self.subscriberVideoView];
    OTError *error = nil;
    [self.session subscribe:self.subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    self.subscriber.audioLevelDelegate = self;
}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    [self.subscriber.view removeFromSuperview];
    self.subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}

- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    // Step 3a: Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == self.subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([self.subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [self.subscriberVideoView setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                          widgetHeight)];
    [self.view addSubview:self.subscriberVideoView];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    NSLog(@"Publishing");
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
    
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Message from video session"
                                                                         message:string
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
    });
}

- (void)     session:(OTSession*)session
archiveStartedWithId:(NSString *)archiveId
                name:(NSString *)name
{
    NSLog(@"session archiving started with id:%@ name:%@", archiveId, name);
    TBExampleOverlayView *overlayView =
    [(TBExampleVideoView *)[self.publisher view] overlayView];
    [overlayView startArchiveAnimation];
}

- (void)     session:(OTSession*)session
archiveStoppedWithId:(NSString *)archiveId
{
    NSLog(@"session archiving stopped with id:%@", archiveId);
    TBExampleOverlayView *overlayView =
    [(TBExampleVideoView *)[self.publisher view] overlayView];
    [overlayView stopArchiveAnimation];
}

- (void)subscriberVideoDisabled:(OTSubscriberKit*)subscriber
                         reason:(OTSubscriberVideoEventReason)reason
{
    [(TBExampleVideoView*)subscriber.videoRender audioOnlyView].hidden = NO;
    
    if (reason == OTSubscriberVideoEventQualityChanged)
        [[(TBExampleVideoView*)subscriber.videoRender overlayView]
         showVideoDisabled];
    
    self.subscriber.audioLevelDelegate = self;
}

- (void)subscriberVideoEnabled:(OTSubscriberKit*)subscriber
                        reason:(OTSubscriberVideoEventReason)reason
{
    [(TBExampleVideoView*)subscriber.videoRender audioOnlyView].hidden = YES;
    
    if (reason == OTSubscriberVideoEventQualityChanged)
        [[(TBExampleVideoView*)subscriber.videoRender overlayView] resetView];
    
    self.subscriber.audioLevelDelegate = nil;
}

- (void)subscriberVideoDisableWarning:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberVideoDisableWarning");
    [[(TBExampleVideoView*)subscriber.videoRender overlayView]
     showVideoMayDisableWarning];
}

- (void)subscriberVideoDisableWarningLifted:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberVideoDisableWarningLifted");
    [[(TBExampleVideoView*)subscriber.videoRender overlayView] resetView];
}

- (void)subscriber:(OTSubscriberKit *)subscriber
 audioLevelUpdated:(float)audioLevel{
    float db = 20 * log10(audioLevel);
    float floor = -40;
    float level = 0;
    if (db > floor) {
        level = db + fabsf(floor);
        level /= fabsf(floor);
    }
    self.subscriberVideoView.audioLevelMeter.level = level;
}

#pragma mark - OTVideoViewDelegate

- (void)videoViewDidToggleCamera:(TBExampleVideoView*)videoView {
    if (videoView == self.publisherVideoView) {
        [((TBExampleVideoCapture*)self.publisher.videoCapture) toggleCameraPosition];
    }
}

- (void)videoView:(TBExampleVideoView*)videoView
publisherWasMuted:(BOOL)publisherMuted
{
    [self.publisher setPublishAudio:!publisherMuted];
}

- (void)videoView:(TBExampleVideoView*)videoView
subscriberVolumeWasMuted:(BOOL)subscriberMuted
{
    [self.subscriber setSubscribeToAudio:!subscriberMuted];
}

@end
