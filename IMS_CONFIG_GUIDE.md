# Free5GC + IMS 配置完成指南

## 一、Windows下载的deb包

请下载以下两个包：

```
http://archive.ubuntu.com/ubuntu/pool/universe/k/kamailio/kamailio_5.5.4-1_amd64.deb
http://archive.ubuntu.com/ubuntu/pool/universe/k/kamailio/kamailio-ims-modules_5.5.4-1_amd64.deb
```

下载后上传到VM：
```powershell
scp kamailio_5.5.4-1_amd64.deb root@10.88.120.99:/home/core/ims-debs/
scp kamailio-ims-modules_5.5.4-1_amd64.deb root@10.88.120.99:/home/core/ims-debs/
```

## 二、安装IMS

上传完成后，在VM上执行：
```bash
cd /home/core/ims-debs
dpkg -i kamailio_5.5.4-1_amd64.deb
dpkg -i kamailio-ims-modules_5.5.4-1_amd64.deb
```

启动IMS服务：
```bash
kamailio -f /etc/kamailio/kamailio.cfg -DD -E
```

## 三、核心网参数配置（已完成）

### AMF参数
- AMF IP: 10.88.120.100
- AMF Port: 38412 (SCTP)
- PLMN: MCC=460, MNC=11
- TAC: 1
- imsVoPS: 1 (IMS语音支持指示)

### 切片配置
- SST: 1
- SD: 000000 或 112233

### DNN配置
- internet: 数据上网 (IP池: 10.60.0.0/16, 5QI=9)
- ims: 语音通话 (IP池: 10.62.0.0/16, 5QI=5)

### IMS服务器
- SIP地址: 10.88.120.99:5060
- Domain: ims.free5gc.org

## 四、手机SIM卡参数

```
IMSI: 460119999999001~010
Key (K): 12345678901234567890123456789012
OP: 12345678901234561234567890123456
AMF: 8000
```

## 五、商用小基站(gNB)配置

```yaml
mcc: "460"
mnc: "11"
tac: 1

# AMF连接
amfConfigs:
  - address: 10.88.120.100
    port: 38412

# 切片
slices:
  - sst: 1
    sd: 0x000000

# IMS配置（语音）
ims:
  address: 10.88.120.99
  port: 5060
```

## 六、测试流程

1. 手机注册到网络
2. 建立internet PDU会话 → 上网
3. 建立ims PDU会话 → IMS注册到Kamailio
4. 发起INVITE → 语音通话

## 七、重启核心网

```bash
cd /home/core
docker-compose restart
# 等待10秒
docker exec upf sh -c 'iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -I FORWARD 1 -j ACCEPT'
```

## 八、验证状态

```bash
# 查看AMF日志
docker logs amf --tail 50

# 查看SMF日志
docker logs smf --tail 50

# 查看已注册UE
docker exec mongodb mongo free5gc --eval 'db.subscribers.find()'
```

---
配置已完成，上传deb包后即可启用语音通话功能！