object ogcvdispensarios_wayne2w: Togcvdispensarios_wayne2w
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 465
  Top = 199
  Height = 191
  Width = 270
  object ServerSocket1: TServerSocket
    Active = False
    Port = 8585
    ServerType = stNonBlocking
    OnClientRead = ServerSocket1ClientRead
    Left = 41
    Top = 37
  end
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
    Left = 171
    Top = 33
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 100
    OnTimer = Timer1Timer
    Left = 106
    Top = 74
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
    Left = 172
    Top = 85
  end
end
