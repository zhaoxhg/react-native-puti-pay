
#import "RNPutiPay.h"
#import <AlipaySDK/AlipaySDK.h>

@implementation RNPutiPay
{
    NSString *wxOpenId;
    NSString *alipayScheme;
    RCTResponseSenderBlock wxCallBack;
    RCTResponseSenderBlock alipayCallBack;
}

RCT_EXPORT_MODULE(PutiPay)

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenURL:) name:@"RCTOpenURLNotification" object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)handleOpenURL:(NSNotification *)aNotification
{
    NSString * aURLString =  [aNotification userInfo][@"url"];
    NSURL * aURL = [NSURL URLWithString:aURLString];
    if ([aURL.host isEqualToString:@"safepay"]) {
        //跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processOrderWithPaymentResult:aURL standbyCallback:^(NSDictionary *resultDic) {
            if (alipayCallBack != nil) {
                alipayCallBack([[NSArray alloc] initWithObjects:resultDic, nil]);
                alipayCallBack = nil;
            }
            NSLog(@"result = %@",resultDic);
        }];
    }
    if ([WXApi handleOpenURL:aURL delegate:self])
    {
        return YES;
    } else {
        return NO;
    }
}

RCT_EXPORT_METHOD(setWxConfig:(NSDictionary *)config){
    wxOpenId = config[@"wxId"];
    [WXApi registerApp:config[@"wxId"] universalLink:config[@"universalLink"]];
}
RCT_EXPORT_METHOD(setAlipayScheme:(NSString *)scheme){
    alipayScheme = scheme;
}
RCT_EXPORT_METHOD(alipay:(NSString *)info callback:(RCTResponseSenderBlock)callback)
{
    alipayCallBack = callback;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[AlipaySDK defaultService] payOrder:info fromScheme:alipayScheme callback:^(NSDictionary *resultDic) {
            NSLog(@"alipay:callback");
            
            callback([[NSArray alloc] initWithObjects:resultDic, nil]);
        }];
    });
}

RCT_EXPORT_METHOD(wxPay:(NSDictionary *)params  callback:(RCTResponseSenderBlock)callback)
{
    
    NSLog(@"wxPay:%@", params);
    //需要创建这个支付对象
    PayReq *req   = [[PayReq alloc] init];
    //由用户微信号和AppID组成的唯一标识，用于校验微信用户
    req.openID = wxOpenId;
    // 商家id，在注册的时候给的
    req.partnerId = params[@"partnerId"];
    // 预支付订单这个是后台跟微信服务器交互后，微信服务器传给你们服务器的，你们服务器再传给你
    req.prepayId= params[@"prepayId"];
    // 根据财付通文档填写的数据和签名
    //这个比较特殊，是固定的，只能是即req.package = Sign=WXPay
    req.package= params[@"packageValue"];
    // 随机编码，为了防止重复的，在后台生成
    req.nonceStr  = params[@"nonceStr"];
    // 这个是时间戳，也是在后台生成的，为了验证支付的
    NSString * stamp = params[@"timeStamp"];
    req.timeStamp = stamp.intValue;
    // 这个签名也是后台做的
    req.sign = params[@"sign"];
    //发送请求到微信，等待微信返回onResp
    dispatch_async(dispatch_get_main_queue(), ^{
        [WXApi sendReq:req completion:^(BOOL success){}];
    });
    wxCallBack = callback;
}

RCT_EXPORT_METHOD(wxMiniPay:(NSDictionary *)params  callback:(RCTResponseSenderBlock)callback)
{
    
    NSLog(@"wxPay:%@", params);
    WXLaunchMiniProgramReq *launchMiniProgramReq = [WXLaunchMiniProgramReq object];
    launchMiniProgramReq.userName = params[@"userName"];  //拉起的小程序的username
    launchMiniProgramReq.path = params[@"path"];    ////拉起小程序页面的可带参路径，不填默认拉起小程序首页，对于小游戏，可以只传入 query 部分，来实现传参效果，如：传入 "?foo=bar"。
    launchMiniProgramReq.miniProgramType = params[@"miniProgramType"]; //拉起小程序的类型（正式版=0| 开发版=1 | 体验版=2）
    //发送请求到微信，等待微信返回onResp
    dispatch_async(dispatch_get_main_queue(), ^{
        [WXApi sendReq:launchMiniProgramReq completion:^(BOOL success){}];
    });
    wxCallBack = callback;
}

- (void)onReq:(BaseReq *)req{
    NSLog(@"onReq%@",req);
}

-(void) onResp:(BaseResp*)resp
{
    if([resp isKindOfClass:[PayResp class]]){
        if (wxCallBack != nil) {
            NSMutableDictionary *data = [NSMutableDictionary new];
            [data setValue:resp.errStr forKey:@"errStr"];
            [data setValue:@(resp.type) forKey:@"type"];
            [data setValue:@(resp.errCode) forKey:@"errCode"];
            wxCallBack([[NSArray alloc] initWithObjects:data, nil]);
            wxCallBack = nil;
        }
    }
    else if ([resp isKindOfClass:[WXLaunchMiniProgramResp class]])
    {
        // NSString *string = resp.extMsg;
        // 对应小程序组件 <button open-type="launchApp"> 中的 app-parameter 属性
        if (wxCallBack != nil) {
            NSMutableDictionary *data = [NSMutableDictionary new];
            [data setValue:resp.errStr forKey:@"errStr"];
            [data setValue:@(resp.type) forKey:@"type"];
            [data setValue:@(resp.errCode) forKey:@"errCode"];
            // [data setValue:string forKey:@"extraData"];
            wxCallBack([[NSArray alloc] initWithObjects:data, nil]);
            wxCallBack = nil;
        }
    }
}
@end
  
