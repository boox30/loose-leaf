//
//  MMCloudKitImportCoordinator.h
//  LooseLeaf
//
//  Created by Adam Wulf on 8/31/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMCloudKitManager.h"
#import "MMAvatarButton.h"

@class MMCloudKitExportView;

@interface MMCloudKitImportCoordinator : NSObject

@property (nonatomic, strong) MMAvatarButton* avatarButton;

-(id) initWithSender:(CKDiscoveredUserInfo*)senderInfo andButton:(MMAvatarButton*)avatarButton andZipFile:(NSString*)zipFile forExportView:(MMCloudKitExportView*)_exportView;

-(void) begin;

@end