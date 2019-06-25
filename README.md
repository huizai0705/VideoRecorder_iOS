# VideoRecorder_iOS
https://blog.csdn.net/m0_37677536/article/details/90439399  
https://blog.csdn.net/m0_37677536/article/details/93216200
代码内容分为两大模块：
一./n
1.基于GPUImage自定义美颜滤镜/n
2.基于GPUImage添加文本水印及动态水印
3.基于GPUImage视频录制
4.录制过程中各种滤镜随意切换，及文本水印动态水印随意切换可以加载gif图作为水印
5.录制过程中可以暂停并继续录制
6.使用AVFoundation框架进行视频拼接
7.获取短视频第一帧图片，示例代码中有方法
二.
1.FFmpeg旧接口编码音视频到MP4文件
2.FFmpeg新接口编码音视频到MP4文件
3.FFmpeg新接口编码音视频并直接推流
4.编码过程中直接AVFilter添加水印
5.FFmpeg直接编码GPUImage输出视频数据
