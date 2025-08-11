object ogcvdispensarios_wayne2w: Togcvdispensarios_wayne2w
  OldCreateOrder = False
  OnDestroy = ServiceDestroy
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStop = ServiceStop
  Left = 465
  Top = 199
  Height = 191
  Width = 270
  object pSerial: TApdComPort
    ComNumber = 1
    Baud = 5700
    Parity = pEven
    Tracing = tlOn
    TraceName = 'APRO.TRC'
    TraceAllHex = True
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    OnTriggerData = pSerialTriggerData
    Left = 150
    Top = 27
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 50
    OnTimer = Timer1Timer
    Left = 56
    Top = 90
  end
  object pSerial2: TApdComPort
    ComNumber = 1
    Baud = 5700
    Parity = pEven
    Tracing = tlOn
    TraceName = 'APRO.TRC'
    TraceAllHex = True
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerial2TriggerAvail
    OnTriggerData = pSerial2TriggerData
    Left = 170
    Top = 92
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 112
    Top = 93
  end
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 73
    Top = 28
  end
end
