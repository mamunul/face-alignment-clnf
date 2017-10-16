//
//  ViewController.m
//  CLNF
//
//  Created by Mamunul on 10/16/17.
//  Copyright © 2017 Mamunul. All rights reserved.
//
#import <opencv2/opencv.hpp>
#import "ViewController.h"


///// opencv

///// C++
#include <iostream>
///// user
#include "FaceARDetectIOS.h"

#define QUEUE_NAME_VIDEO "com.ipvision.camera.samplebufferqueue"

@interface ViewController(){

	unsigned char* yBuffer;
	unsigned char* uvBuffer;
	int numOfPixels;
	cv::Mat targetImage;
	int frame_count;
}
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	// Do any additional setup after loading the view, typically from a nib.


	// Do any additional setup after loading the view.
	
	frame_count = 0;
	
	targetImage.create(1280,720,CV_8UC1);
	
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	[session setSessionPreset:AVCaptureSessionPreset1280x720];
	
	AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	NSArray *devices = AVCaptureDevice.devices;
	for(AVCaptureDevice *device in devices) {
		
		if(device.position == AVCaptureDevicePositionFront) {
			
			videoDevice = device;
			break;
		}
	}
	AVCaptureDeviceInput *capInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
	if (capInput) [session addInput:capInput];
	
	dispatch_queue_t videoBufferQueue = dispatch_queue_create(QUEUE_NAME_VIDEO, DISPATCH_QUEUE_SERIAL);
	AVCaptureVideoDataOutput *videoDataOutput =  [[AVCaptureVideoDataOutput alloc] init];
	[videoDataOutput setSampleBufferDelegate:self queue:videoBufferQueue];
	
	NSDictionary *videoDataSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
																  forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	videoDataOutput.videoSettings = videoDataSettings;
	
	if([session canAddOutput:videoDataOutput]) {
		
		[session addOutput:videoDataOutput];
	}
	AVCaptureConnection *videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
	if (videoConnection) {
		
		videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
	}
	
	numOfPixels = 720*1280;
	
	yBuffer = new unsigned char[numOfPixels];
	uvBuffer = new unsigned char[numOfPixels / 2];
	
	AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	
	previewLayer.frame = self.view.bounds;
	
	[self.view.layer addSublayer:previewLayer];
	
	[session startRunning];
	
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
	
	

	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	// lock pixel buffer
	CVPixelBufferLockBaseAddress(imageBuffer, 0);
	const unsigned char* yBuf = (unsigned char*)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
	memcpy(yBuffer, yBuf, numOfPixels);
	memcpy(targetImage.data, yBuf, numOfPixels);
	CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	
	CVPixelBufferLockBaseAddress(imageBuffer, 1);
	const unsigned char* uvBuf = (unsigned char*)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
	memcpy(uvBuffer, uvBuf, numOfPixels/2);
	CVPixelBufferUnlockBaseAddress(imageBuffer, 1);
	
	float fx, fy, cx, cy;
	cx = 1.0*targetImage.cols / 2.0;
	cy = 1.0*targetImage.rows / 2.0;
	
	fx = 500 * (targetImage.cols / 1280.0);
	fy = 500 * (targetImage.rows / 720.0);
	
	fx = (fx + fy) / 2.0;
	fy = fx;
	
	[[FaceARDetectIOS alloc] run_FaceAR:targetImage frame__:frame_count fx__:fx fy__:fy cx__:cx cy__:cy];
	frame_count = frame_count + 1;
	


}


- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];

	// Update the view, if already loaded.
}


@end
