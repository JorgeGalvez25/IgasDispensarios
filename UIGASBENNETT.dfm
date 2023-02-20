object ogcvdispensarios_bennett: Togcvdispensarios_bennett
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 1119
  Top = 349
  Height = 194
  Width = 290
  object ServerSocket1: TServerSocket
    Active = False
    Port = 8585
    ServerType = stNonBlocking
    OnClientRead = ServerSocket1ClientRead
    Left = 34
    Top = 32
  end
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 100
    Top = 31
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 150
    OnTimer = Timer1Timer
    Left = 47
    Top = 96
  end
end
