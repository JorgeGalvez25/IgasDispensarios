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
    Left = 168
    Top = 39
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 100
    OnTimer = Timer1Timer
    Left = 106
    Top = 74
  end
end
