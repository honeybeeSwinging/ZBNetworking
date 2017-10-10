//
//  ZBRequestManager.m
//  ZBNetworkingDemo
//
//  Created by NQ UEC on 2017/8/17.
//  Copyright © 2017年 Suzhibin. All rights reserved.
//

#import "ZBRequestManager.h"
#import "ZBCacheManager.h"
#import "ZBRequestEngine.h"
#import "ZBURLRequest.h"
#import "NSFileManager+ZBPathMethod.h"
@implementation ZBRequestManager

#pragma mark - 配置请求
+ (void)requestWithConfig:(requestConfig)config success:(requestSuccess)success failed:(requestFailed)failed{
    [self requestWithConfig:config progress:nil success:success failed:failed];
}

+ (void)requestWithConfig:(requestConfig)config progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    ZBURLRequest *request=[[ZBURLRequest alloc]init];
    config ? config(request) : nil;
    
    [self sendRequest:request progress:progress success:success failed:failed];
}

+ (ZBBatchRequest *)batchRequest:(batchRequestConfig)config success:(requestSuccess)success failed:(requestFailed)failed{
    return [self batchRequest:config progress:nil success:success failed:failed];
}

+ (ZBBatchRequest *)batchRequest:(batchRequestConfig)config progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    ZBBatchRequest *batchRequest=[[ZBBatchRequest alloc]init];
    config ? config(batchRequest) : nil;
    
    if (batchRequest.urlArray.count==0)return nil;
    [batchRequest.urlArray enumerateObjectsUsingBlock:^(ZBURLRequest *request , NSUInteger idx, BOOL *stop) {
        [self sendRequest:request progress:progress success:success failed:failed];
    }];
    return batchRequest;
}

+ (void)sendRequest:(ZBURLRequest *)request progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    if (request.methodType==ZBMethodTypePOST) {
        
        [self postRequest:request progress:progress success:success failed:failed];
    }else if (request.methodType==ZBMethodTypeUpload){
        
        [self uploadWithRequest:request progress:progress success:success failed:failed];
    }else if (request.methodType==ZBMethodTypeDownLoad){
        
        [self downloadWithRequest:request progress:progress success:success failed:failed];
    }else{
        
        [self getRequest:request progress:progress success:success failed:failed];
    }
}

#pragma mark - GET
+ (void)getRequest:(ZBURLRequest *)request progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    NSString *key = [NSString zb_stringUTF8Encoding:[NSString zb_urlString:request.urlString appendingParameters:request.parameters]];
    
    if ([[ZBCacheManager sharedInstance]diskCacheExistsWithKey:key]&&request.apiType!=ZBRequestTypeRefresh&&request.apiType!=ZBRequestTypeRefreshMore){
        
        [[ZBCacheManager sharedInstance]getCacheDataForKey:key value:^(NSData *data,NSString *filePath) {
            success ? success(data ,request.apiType) : nil;
        }];
        
    }else{
        [self dataTaskWithGetRequest:request progress:progress success:success failed:failed];
    }
}

+ (NSURLSessionDataTask *)dataTaskWithGetRequest:(ZBURLRequest *)request progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    [self serializer:request];
    [self headersAndTime:request];
    
    return  [self dataTaskWithGetURL:request.urlString parameters:request.parameters  progress:progress success:^(id responseObject, apiType type) {
        
        [self storeObject:responseObject request:request];
        
        success ? success(responseObject,request.apiType) : nil;
    } failed:failed];
}

+ (NSURLSessionDataTask *)dataTaskWithGetURL:(NSString *)urlString parameters:(id)parameters  progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    if([urlString isEqualToString:@""]||urlString==nil)return nil;
    
    NSURLSessionDataTask *dataTask = nil;
    return dataTask= [[ZBRequestEngine defaultEngine]GET:[NSString zb_stringUTF8Encoding:urlString] parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
        
        progress ? progress(downloadProgress) : nil;
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        success ? success(responseObject,0) : nil;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failed ? failed(error) : nil;
    }];
}

#pragma mark - POST
+ (void)postRequest:(ZBURLRequest *)request  progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    NSString *key = [NSString zb_stringUTF8Encoding:[NSString zb_urlString:request.urlString appendingParameters:request.parameters]];
    
    if ([[ZBCacheManager sharedInstance]diskCacheExistsWithKey:key]&&request.apiType!=ZBRequestTypeRefresh&&request.apiType!=ZBRequestTypeRefreshMore){
    
        [[ZBCacheManager sharedInstance]getCacheDataForKey:key value:^(NSData *data,NSString *filePath) {
            success ? success(data ,request.apiType) : nil;
        }];
        
    }else{
        [self dataTaskWithPostRequest:request apiType:request.apiType progress:progress success:success failed:failed];
    }
}

+ (NSURLSessionDataTask *)dataTaskWithPostRequest:(ZBURLRequest *)request apiType:(apiType)type progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    [self serializer:request];
    [self headersAndTime:request];
    
    return  [self dataTaskWithPostURL:request.urlString parameters:request.parameters  progress:progress success:^(id responseObject, apiType type) {
        
        [self storeObject:responseObject request:request];
        
        success ? success(responseObject,request.apiType) : nil;
    } failed:failed];
}

+ (NSURLSessionDataTask *)dataTaskWithPostURL:(NSString *)urlString parameters:(id)parameters  progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    if([urlString isEqualToString:@""]||urlString==nil)return nil;
    
    NSURLSessionDataTask *dataTask = nil;
    return dataTask=[[ZBRequestEngine defaultEngine] POST:[NSString zb_stringUTF8Encoding:urlString] parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        
        progress ? progress(uploadProgress) : nil;
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
  
        success ? success(responseObject,0) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failed ? failed(error) : nil;
    }];
}

#pragma mark - upload
+ (NSURLSessionTask *)uploadWithRequest:(ZBURLRequest *)request
                           progress:(progressBlock)progress
                            success:(requestSuccess)success
                            failed:(requestFailed)failed{
    
    return [[ZBRequestEngine defaultEngine] POST:[NSString zb_stringUTF8Encoding:request.urlString] parameters:request.parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        [request.uploadDatas enumerateObjectsUsingBlock:^(ZBUploadData *obj, NSUInteger idx, BOOL *stop) {
            if (obj.fileData) {
                if (obj.fileName && obj.mimeType) {
                    [formData appendPartWithFileData:obj.fileData name:obj.name fileName:obj.fileName mimeType:obj.mimeType];
                } else {
                    [formData appendPartWithFormData:obj.fileData name:obj.name];
                }
            } else if (obj.fileURL) {
    
                if (obj.fileName && obj.mimeType) {
                    [formData appendPartWithFileURL:obj.fileURL name:obj.name fileName:obj.fileName mimeType:obj.mimeType error:nil];
                } else {
                    [formData appendPartWithFileURL:obj.fileURL name:obj.name error:nil];
                }
        
            }
        }];

    } progress:^(NSProgress * _Nonnull uploadProgress) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        success ? success(responseObject,0) : nil;
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error){
        failed ? failed(error) : nil;

    }];
}

#pragma mark - DownLoad
+ (NSURLSessionTask *)downloadWithRequest:(ZBURLRequest *)request progress:(progressBlock)progress success:(requestSuccess)success failed:(requestFailed)failed{
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString zb_stringUTF8Encoding:request.urlString]]];
    
    [self headersAndTime:request];
    
    NSURL *downloadFileSavePath;
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:request.downloadSavePath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadFileSavePath = [NSURL fileURLWithPath:[NSString pathWithComponents:@[request.downloadSavePath, fileName]] isDirectory:NO];
    } else {
        downloadFileSavePath = [NSURL fileURLWithPath:request.downloadSavePath isDirectory:NO];
    }
    NSURLSessionDownloadTask *dataTask = [[ZBRequestEngine defaultEngine] downloadTaskWithRequest:urlRequest progress:^(NSProgress * _Nonnull downloadProgress) {
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(downloadProgress) : nil;
        });
    
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return downloadFileSavePath;
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        failed ? failed(error) : nil;
        success ? success([filePath path],request.apiType) : nil;
    }];

    [dataTask resume];
    return dataTask;
}

#pragma mark - 其他配置
+ (void)storeObject:(NSObject *)object request:(ZBURLRequest *)request{
    NSString * key= [NSString zb_stringUTF8Encoding:[NSString zb_urlString:request.urlString appendingParameters:request.parameters]];
    [[ZBCacheManager sharedInstance] storeContent:object forKey:key isSuccess:nil];
}

+ (void)serializer:(ZBURLRequest *)request{
    
    [ZBRequestEngine defaultEngine].requestSerializer =request.requestSerializer==ZBSerializerHTTP ? [AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
}

+ (void)headersAndTime:(ZBURLRequest *)request{
    
    [ZBRequestEngine defaultEngine].requestSerializer.timeoutInterval=request.timeoutInterval?request.timeoutInterval:15;
    
    if ([[request mutableHTTPRequestHeaders] allKeys].count>0) {
        [[request mutableHTTPRequestHeaders] enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [[ZBRequestEngine defaultEngine].requestSerializer setValue:value forHTTPHeaderField:field];
        }];
    }
}

+ (void)cancelRequest:(NSString *)urlString completion:(cancelCompletedBlock)completion{
    
    if([urlString isEqualToString:@""]||urlString==nil)return;
    
    NSString *cancelUrlString=[[ZBRequestEngine defaultEngine]cancelRequest:[NSString zb_stringUTF8Encoding:urlString]];
    if (completion) {
        completion(cancelUrlString);
    }
}

@end
