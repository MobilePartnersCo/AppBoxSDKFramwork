//
//  FSCalendarDynamicHeader.h
//  Pods
//
//  Created by DingWenchao on 6/29/15.
//
//  动感头文件，仅供框架内部使用。
//  Private header, don't use it.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import <AppBoxSDK/FSCalendar.h>
#import <AppBoxSDK/FSCalendarCell.h>
#import <AppBoxSDK/FSCalendarHeaderView.h>
#import <AppBoxSDK/FSCalendarStickyHeader.h>
#import <AppBoxSDK/FSCalendarCollectionView.h>
#import <AppBoxSDK/FSCalendarCollectionViewLayout.h>
#import <AppBoxSDK/FSCalendarCalculator.h>
#import <AppBoxSDK/FSCalendarTransitionCoordinator.h>
#import <AppBoxSDK/FSCalendarDelegationProxy.h>

@interface FSCalendar (Dynamic)

@property (readonly, nonatomic) FSCalendarCollectionView *collectionView;
@property (readonly, nonatomic) FSCalendarCollectionViewLayout *collectionViewLayout;
@property (readonly, nonatomic) FSCalendarTransitionCoordinator *transitionCoordinator;
@property (readonly, nonatomic) FSCalendarCalculator *calculator;
@property (readonly, nonatomic) BOOL floatingMode;
@property (readonly, nonatomic) NSArray *visibleStickyHeaders;
@property (readonly, nonatomic) CGFloat preferredHeaderHeight;
@property (readonly, nonatomic) CGFloat preferredWeekdayHeight;

@property (readonly, nonatomic) NSCalendar *gregorian;
@property (readonly, nonatomic) NSDateFormatter *formatter;

@property (readonly, nonatomic) UIView *contentView;
@property (readonly, nonatomic) UIView *daysContainer;

@property (assign, nonatomic) BOOL needsAdjustingViewFrame;

- (void)adjustMonthPosition;
- (void)configureAppearance;

- (CGSize)sizeThatFits:(CGSize)size scope:(FSCalendarScope)scope;

@end

@interface FSCalendarAppearance (Dynamic)

@property (readwrite, nonatomic) FSCalendar *calendar;

@property (readonly, nonatomic) NSDictionary *backgroundColors;
@property (readonly, nonatomic) NSDictionary *titleColors;
@property (readonly, nonatomic) NSDictionary *subtitleColors;
@property (readonly, nonatomic) NSDictionary *borderColors;

@end

@interface FSCalendarWeekdayView (Dynamic)

@property (readwrite, nonatomic) FSCalendar *calendar;

@end

@interface FSCalendarCollectionViewLayout (Dynamic)

@property (readonly, nonatomic) CGSize estimatedItemSize;

@end

@interface FSCalendarDelegationProxy()<FSCalendarDataSource,FSCalendarDelegate,FSCalendarDelegateAppearance>
@end


