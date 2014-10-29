//
//  ViewController.m
//  RatioCityDataApp
//
//  Created by Bennett Lin on 10/27/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "ViewController.h"

#define kDepartmentKey @"department"
#define kFemaleWageKey @"female_avg_hrly_rate"
#define kMaleWageKey @"male_avg_hrly_rate"
#define kModernFont @"FilmotypeModern"
#define kAnimationTime 0.5f

@interface ViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (strong, nonatomic) UIImageView *femaleImageView;
@property (strong, nonatomic) UIImageView *maleImageView;

@property (strong, nonatomic) UIView *femaleBarView;
@property (strong, nonatomic) UIView *maleBarView;

@property (strong, nonatomic) UILabel *femaleWageLabel;
@property (strong, nonatomic) UILabel *maleWageLabel;
@property (strong, nonatomic) UIPickerView *deptPickerView;

@property (strong, nonatomic) NSURLSession *session;
@property (copy, nonatomic) void(^taskCompletion)(NSData *data, NSURLResponse *response, NSError *error);

@property (strong, nonatomic) NSArray *allDepartments;

@property (assign, nonatomic) NSDecimalNumber *pickedFemaleWage;
@property (assign, nonatomic) NSDecimalNumber *pickedMaleWage;

@end

@implementation ViewController {

  CGFloat _labelFontSize;
  CGFloat _pickerFontSize;
  
  CGFloat _barViewStaticYOrigin;
  CGFloat _barViewStaticWidth;
  CGFloat _barViewStaticHeight;
  
  NSDecimalNumber *_highestWage;
}

@synthesize session = _session;
@synthesize taskCompletion = _taskCompletion;

-(void)viewDidLoad {
  [super viewDidLoad];
  
  self.femaleImageView = [UIImageView new];
  self.maleImageView = [UIImageView new];
  [self.view addSubview:self.femaleImageView];
  [self.view addSubview:self.maleImageView];
  
  _barViewStaticYOrigin = 0.f;
  self.femaleBarView = [UIView new];
  self.maleBarView = [UIView new];
  UIColor *darkGreenColour = [UIColor colorWithRed:0x1f/255.f green:0x55/255.f blue:0x13/255.f alpha:0xff/255.f];
  self.femaleBarView.backgroundColor = darkGreenColour;
  self.maleBarView.backgroundColor = darkGreenColour;
  
  [self.view addSubview:self.femaleBarView];
  [self.view addSubview:self.maleBarView];
  
  _highestWage = 0;
  _labelFontSize = 40.f;
  self.pickedFemaleWage = [NSDecimalNumber notANumber];
  self.pickedMaleWage = [NSDecimalNumber notANumber];
  self.femaleWageLabel = [UILabel new];
  self.maleWageLabel = [UILabel new];
  self.femaleWageLabel.adjustsFontSizeToFitWidth = YES;
  self.maleWageLabel.adjustsFontSizeToFitWidth = YES;
  self.femaleWageLabel.textAlignment = NSTextAlignmentCenter;
  self.maleWageLabel.textAlignment = NSTextAlignmentCenter;
  
  [self.view addSubview:self.femaleWageLabel];
  [self.view addSubview:self.maleWageLabel];
  
  _pickerFontSize = 36.f;
  self.deptPickerView = [UIPickerView new];
  self.deptPickerView.delegate = self;
  self.deptPickerView.dataSource = self;
  [self.view addSubview:self.deptPickerView];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutStaticViewElements) name:UIDeviceOrientationDidChangeNotification object:nil];
  
  UIFont *modernFont = [UIFont fontWithName:kModernFont size:_labelFontSize];
  self.femaleWageLabel.font = modernFont;
  self.maleWageLabel.font = modernFont;
  
  NSString *genderWageURLString = @"https://data.seattle.gov/resource/5jqs-k4qf.json?$where=age_range IS NULL";
  NSURLRequest *genderWageRequest = [self requestForURLString:genderWageURLString];
  
  NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:genderWageRequest completionHandler:self.taskCompletion];
  
  [dataTask resume];
}

#pragma mark - session methods

-(NSArray *)sortedDeptArrayFromJsonArray:(NSArray *)jsonArray {
  NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:jsonArray.count];
  
    // create a dictionary for each department
  for (NSDictionary *jsonDeptDictionary in jsonArray) {
    
    NSString *deptName = jsonDeptDictionary[kDepartmentKey];
    
      // don't show "Grand Total" dictionary
    if (![deptName isEqualToString:@"Grand Total"]) {
      
        // remove "Total" from department name
      NSString *abridgedDeptName = [deptName stringByReplacingOccurrencesOfString:@" Total" withString:@""];
      
        // check if value exists for key
      NSDecimalNumber *femaleWage = [jsonDeptDictionary objectForKey:kFemaleWageKey] ?
          [NSDecimalNumber decimalNumberWithString:jsonDeptDictionary[kFemaleWageKey]] : [NSDecimalNumber notANumber];
      
        // highest wage sets maximum bar height
      if ([femaleWage compare:_highestWage] == NSOrderedDescending) {
        _highestWage = femaleWage;
      }
      
      NSDecimalNumber *maleWage = [jsonDeptDictionary objectForKey:kMaleWageKey] ?
          [NSDecimalNumber decimalNumberWithString:jsonDeptDictionary[kMaleWageKey]] : [NSDecimalNumber notANumber];
      
      if ([maleWage compare:_highestWage] == NSOrderedDescending) {
        _highestWage = maleWage;
      }
      
      NSDictionary *deptDictionary = [NSDictionary dictionaryWithObjects:@[abridgedDeptName, femaleWage, maleWage] forKeys:@[kDepartmentKey, kFemaleWageKey, kMaleWageKey]];
      
      [tempArray addObject:deptDictionary];
    }
  }

  return [self sortArrayByDepartment:tempArray];
}

#pragma mark - session accessor methods

-(NSURLSession *)session {
  if (!_session) {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:configuration];
  }
  return _session;
}

-(void(^)(NSData *data, NSURLResponse *response, NSError *error))taskCompletion {
  
  if (!_taskCompletion) {
    
    __weak typeof(self) weakSelf = self;
    
    _taskCompletion = ^void(NSData *data, NSURLResponse *response, NSError *error) {
      
      if (!error) {
        NSError *jsonError;
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        
        if (!jsonError) {
          
          weakSelf.allDepartments = [weakSelf sortedDeptArrayFromJsonArray:jsonArray];
          
            // reload picker
          dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf reloadAndResetPicker:weakSelf.deptPickerView];
          });
          
        } else {
          NSLog(@"%@", jsonError.localizedDescription);
        }
      } else {
        NSLog(@"%@", error.localizedDescription);
      }
    };
  }
  
  return _taskCompletion;
}

#pragma mark - picker methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
  return self.allDepartments.count;
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
  return _pickerFontSize * 1.25;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
  
  UILabel *textView = (UILabel *)view;
  
  if (!textView) {
    textView = [UILabel new];
    textView.font = [UIFont fontWithName:kModernFont size:_pickerFontSize];
    textView.textAlignment = NSTextAlignmentCenter;
    textView.adjustsFontSizeToFitWidth = YES;
  }

  NSDictionary *deptDictionary = self.allDepartments[row];
  textView.text = deptDictionary[kDepartmentKey];
  return textView;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
  NSDictionary *deptDictionary = self.allDepartments[row];
  
    // show female image only if wage exists
  if (deptDictionary[kFemaleWageKey] == [NSDecimalNumber notANumber]) {
    self.femaleImageView.image = nil;
  } else {
    self.femaleImageView.image = [self imageForRow:row isFemale:YES];
  }
  
    // show male image only if wage exists (currently no males in Hearing Examiner dept)
  if (deptDictionary[kMaleWageKey] == [NSDecimalNumber notANumber]) {
    self.maleImageView.image = nil;
  } else {
    self.maleImageView.image = [self imageForRow:row isFemale:NO];
  }

  self.pickedFemaleWage = deptDictionary[kFemaleWageKey];
  self.pickedMaleWage = deptDictionary[kMaleWageKey];
  
  [self layoutDynamicViewElementsAnimated:YES];
  
  self.femaleWageLabel.text = [self dollarSignTextForWage:self.pickedFemaleWage];
  self.maleWageLabel.text = [self dollarSignTextForWage:self.pickedMaleWage];
}

-(void)reloadAndResetPicker:(UIPickerView *)pickerView {
  [pickerView reloadComponent:0];
  [self pickerView:pickerView didSelectRow:0 inComponent:0];
}

#pragma mark - image view methods

-(UIImage *)imageForRow:(NSUInteger)index isFemale:(BOOL)isFemale {
  
    // from http://all-free-download.com/free-vector/vector-icon/free_vector_business_people_icons_148012.html
    // images are numbered 1 to 20
    // first ten are female, next ten are male
  NSUInteger imageNumber = 1 + (index % 10) + (isFemale ? 0 : 10);

  NSString *imageName = (imageNumber < 10) ?
      [NSString stringWithFormat:@"business_person-0%lu", (unsigned long)imageNumber] :
      [NSString stringWithFormat:@"business_person-%lu", (unsigned long)imageNumber];
  
  return [UIImage imageNamed:imageName];
}

#pragma mark - layout methods

-(void)layoutStaticViewElements {
  
  CGFloat screenWidth = self.view.bounds.size.width;
  CGFloat screenHeight = self.view.bounds.size.height;

    // in portrait, imageViews are 1/3 of screen width;
    // in landscape, imageViews are 1/6 of screen width
  CGFloat imageViewWidth = (screenWidth < screenHeight) ? screenWidth / 3 : screenWidth / 6;
  CGFloat imageViewHeight = imageViewWidth * 1.4;
  
  _barViewStaticWidth = imageViewWidth * 3/4;
  _barViewStaticHeight = imageViewHeight * 2/3;
  
  const CGFloat pickerWidth = 300.f;
  const CGFloat pickerHeight = 216.f;
  
    // space between imageViews and screen edges
  CGFloat imageWidthMargin = (screenWidth - imageViewWidth * 2) / 3;
  CGFloat pickerWidthMargin = (screenWidth - pickerWidth) / 2;
  
    // space between imageViews, barViews, pickerView, and screen edge
  CGFloat heightMargin = (screenHeight - imageViewHeight - pickerHeight - _barViewStaticHeight) / 4;
  
  self.femaleImageView.frame = CGRectMake(imageWidthMargin, heightMargin, imageViewWidth, imageViewHeight);
  self.maleImageView.frame = CGRectMake(imageWidthMargin * 2 + imageViewWidth, heightMargin, imageViewWidth, imageViewHeight);
  
  self.deptPickerView.frame = CGRectMake(pickerWidthMargin, screenHeight - heightMargin - pickerHeight, pickerWidth, pickerHeight);
  
    // space between imageView and label
  const CGFloat barHeightMargin = _labelFontSize * 1.25;
  _barViewStaticYOrigin = heightMargin + imageViewHeight + barHeightMargin;
  [self layoutDynamicViewElementsAnimated:NO];
}

-(void)layoutDynamicViewElementsAnimated:(BOOL)animated {

    // no bar if no wage for this department
  CGFloat femaleWageHeight = (self.pickedFemaleWage == [NSDecimalNumber notANumber]) ?
      0 : [[self.pickedFemaleWage decimalNumberByDividingBy:_highestWage] floatValue] * _barViewStaticHeight;
  CGFloat maleWageHeight = (self.pickedMaleWage == [NSDecimalNumber notANumber]) ?
      0 : [[self.pickedMaleWage decimalNumberByDividingBy:_highestWage] floatValue] * _barViewStaticHeight;
  
    // established desired frames
  CGRect desiredFemaleBarFrame = CGRectMake(self.femaleImageView.frame.origin.x + (self.femaleImageView.frame.size.width / 6), _barViewStaticYOrigin + _barViewStaticHeight - femaleWageHeight, _barViewStaticWidth, femaleWageHeight);
  CGRect desiredMaleBarFrame = CGRectMake(self.maleImageView.frame.origin.x + (self.maleImageView.frame.size.width / 6), _barViewStaticYOrigin + _barViewStaticHeight - maleWageHeight, _barViewStaticWidth, maleWageHeight);
  
  CGRect desiredFemaleLabelFrame = CGRectMake(self.femaleImageView.frame.origin.x + (self.femaleImageView.frame.size.width / 6), _barViewStaticYOrigin + _barViewStaticHeight - femaleWageHeight - _labelFontSize, _barViewStaticWidth, _labelFontSize);
  CGRect desiredMaleLabelFrame = CGRectMake(self.maleImageView.frame.origin.x + (self.maleImageView.frame.size.width / 6), _barViewStaticYOrigin + _barViewStaticHeight - maleWageHeight - _labelFontSize, _barViewStaticWidth, _labelFontSize);
  
  __weak typeof(self) weakSelf = self;
  
  void(^frameAndCenterChanges)(void) = ^void(void) {
    weakSelf.femaleBarView.frame = desiredFemaleBarFrame;
    weakSelf.maleBarView.frame = desiredMaleBarFrame;
    
    weakSelf.femaleBarView.center = CGPointMake(weakSelf.femaleImageView.center.x, weakSelf.femaleBarView.center.y);
    weakSelf.maleBarView.center = CGPointMake(weakSelf.maleImageView.center.x, weakSelf.maleBarView.center.y);
    
    weakSelf.femaleWageLabel.frame = desiredFemaleLabelFrame;
    weakSelf.maleWageLabel.frame = desiredMaleLabelFrame;
    
    weakSelf.femaleWageLabel.center = CGPointMake(weakSelf.femaleImageView.center.x, weakSelf.femaleWageLabel.center.y);
    weakSelf.maleWageLabel.center = CGPointMake(weakSelf.maleImageView.center.x, weakSelf.maleWageLabel.center.y);
  };
  
  if (animated) {
    [UIView animateWithDuration:kAnimationTime animations:frameAndCenterChanges];
    
    // will not animate when view appears and when orientation changes
  } else {
    dispatch_async(dispatch_get_main_queue(), frameAndCenterChanges);
  }
}

#pragma mark - helper methods

-(NSString *)dollarSignTextForWage:(NSDecimalNumber *)wage {

    // if no wage, don't show text
  if (wage == [NSDecimalNumber notANumber]) {
    return @"";
    
  } else {
    return [NSString stringWithFormat:@"$%@", [wage stringValue]];
  }
}

-(NSURLRequest *)requestForURLString:(NSString *)urlString {
  NSString *escapedString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  NSURL *url = [NSURL URLWithString:escapedString];
  return [NSURLRequest requestWithURL:url];
}

-(NSArray *)sortArrayByDepartment:(NSArray *)departmentArray {
  NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kDepartmentKey ascending:YES];
  return [departmentArray sortedArrayUsingDescriptors:@[descriptor]];
}

@end
