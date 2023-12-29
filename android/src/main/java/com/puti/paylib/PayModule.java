package com.puti.paylib;

import android.widget.Toast;

import com.alipay.sdk.app.PayTask;
import com.alipay.sdk.app.EnvUtils;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.tencent.mm.opensdk.modelbiz.WXLaunchMiniProgram;
import com.tencent.mm.opensdk.modelpay.PayReq;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;

import java.util.Map;

/**
 * Created by puti on 2017/11/23.
 */

public class PayModule extends ReactContextBaseJavaModule {


    public static String WX_APPID = "";


    public PayModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "PutiPay";
    }

    @ReactMethod
    public void setAlipaySandbox(Boolean isSandbox) {
        if(isSandbox){
            EnvUtils.setEnv(EnvUtils.EnvEnum.SANDBOX);
        }else {
            EnvUtils.setEnv(EnvUtils.EnvEnum.ONLINE);
        }
    }

    @ReactMethod
    public void alipay(final String orderInfo, final Callback promise) {
        Runnable payRunnable = new Runnable() {
            @Override
            public void run() {
                PayTask alipay = new PayTask(getCurrentActivity());
                Map<String, String> result = alipay.payV2(orderInfo, true);
                WritableMap map = Arguments.createMap();
                map.putString("memo", result.get("memo"));
                map.putString("result", result.get("result"));
                map.putString("resultStatus", result.get("resultStatus"));
                promise.invoke(map);
            }
        };
        // 必须异步调用
        Thread payThread = new Thread(payRunnable);
        payThread.start();
    }

    @ReactMethod
    public void setWxId(String id) {
        WX_APPID = id;
    }

    @ReactMethod
    public void wxPay(ReadableMap params, final Callback callback) {
        IWXAPI api = WXAPIFactory.createWXAPI(getCurrentActivity(), WX_APPID);
        //data  根据服务器返回的json数据创建的实体类对象
        PayReq req = new PayReq();
        req.appId = WX_APPID;
        req.partnerId = params.getString("partnerId");
        req.prepayId = params.getString("prepayId");
        req.packageValue = params.getString("packageValue");
        req.nonceStr = params.getString("nonceStr");
        req.timeStamp = params.getString("timeStamp");
        req.sign = params.getString("sign");
        api.registerApp(WX_APPID);
        XWXPayEntryActivity.callback = new WXPayCallBack() {
            @Override
            public void callBack(WritableMap result) {
                callback.invoke(result);
            }
        };
        //发起请求
        api.sendReq(req);
    }

    @ReactMethod
    public void wxMiniPay(ReadableMap params, final Callback callback) {
        IWXAPI api = WXAPIFactory.createWXAPI(getCurrentActivity(), WX_APPID);

        WXLaunchMiniProgram.Req req = new WXLaunchMiniProgram.Req();
        req.userName = params.getString("userName");            // 填小程序原始id
        req.path = params.getString("path");                  ////拉起小程序页面的可带参路径，不填默认拉起小程序首页，对于小游戏，可以只传入 query 部分，来实现传参效果，如：传入 "?foo=bar"。
//        req.miniprogramType = WXLaunchMiniProgram.Req.MINIPTOGRAM_TYPE_RELEASE;// 可选打开 开发版，体验版和正式版
        req.miniprogramType = params.getInt("miniprogramType");// 正式版=0| 开发版=1 | 体验版=2
//        Toast.makeText(getCurrentActivity(), (req.userName+","+req.path+","+WX_APPID), Toast.LENGTH_SHORT).show();
        XWXPayEntryActivity.callback = new WXPayCallBack() {
            @Override
            public void callBack(WritableMap result) {
                callback.invoke(result);
            }
        };
        api.sendReq(req);
    }
}
