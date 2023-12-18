object ogcvdispensarios_gilbarco2W: Togcvdispensarios_gilbarco2W
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 301
  Top = 204
  Height = 191
  Width = 210
  object ServerSocket1: TServerSocket
    Active = False
    Port = 1001
    ServerType = stNonBlocking
    OnClientRead = ServerSocket1ClientRead
    Left = 35
    Top = 32
  end
  object pSerial: TApdComPort
    Baud = 5700
    Tracing = tlOn
    TraceName = 'APRO.TRC'
    TraceAllHex = True
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    OnTriggerData = pSerialTriggerData
    Left = 99
    Top = 30
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 100
    OnTimer = Timer1Timer
    Left = 48
    Top = 96
  end
end
