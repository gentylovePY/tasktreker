//
//  MQTTManager.swift
//  tasktreker
//
//  Created by Роман Гиниятов on 25.06.2025.
//

import Foundation
import CocoaMQTT

class MQTTManager: ObservableObject {
    static let shared = MQTTManager()
    private var mqtt: CocoaMQTT?
    
    @Published var connectedDevices: [Device] = []
    @Published var connectionStatus: String = "Disconnected"
    
    private init() {
        setupMQTT()
    }
    
    private func setupMQTT() {
        let clientID = "iOS-\(UUID().uuidString)"
        mqtt = CocoaMQTT(clientID: clientID, host: "wegkerrr.com", port: 1883)
        mqtt?.username = "gentylo"
        mqtt?.password = "1we1e12"
        mqtt?.keepAlive = 60
        mqtt?.delegate = self
        mqtt?.autoReconnect = true
        mqtt?.connect()
    }
    
    func subscribeToDeviceTopics(devices: [Device]) {
        guard let mqtt = mqtt, mqtt.connState == .connected else { return }
        
        for device in devices {
            if let topic = device.mqttTopic {
                mqtt.subscribe("\(topic)/status")
                connectedDevices.append(device)
            }
        }
    }
    
    func controlDevice(device: Device, command: String) {
        guard let mqtt = mqtt, mqtt.connState == .connected,
              let topic = device.mqttTopic else { return }
        
        mqtt.publish("\(topic)/control", withString: command)
    }
    
    func updateDeviceStatus(deviceId: String, isOnline: Bool) {
        if let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) {
            connectedDevices[index].isOnline = isOnline
        }
    }
}

extension MQTTManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        DispatchQueue.main.async {
            self.connectionStatus = ack == .accept ? "Connected" : "Connection Failed"
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let topic = message.topic
        let payload = message.string ?? ""
        

        if topic.contains("/status") {
            let deviceId = topic.replacingOccurrences(of: "/status", with: "")
            let isOnline = payload.lowercased() == "online"
            updateDeviceStatus(deviceId: deviceId, isOnline: isOnline)
        }
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            mqtt.connect()
        }
    }
    

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    func mqttDidPing(_ mqtt: CocoaMQTT) {}
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
}
