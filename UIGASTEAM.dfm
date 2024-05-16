object ogcvdispensarios_team: Togcvdispensarios_team
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 241
  Top = 2
  Height = 203
  Width = 213
  object ServerSocket1: TServerSocket
    Active = False
    Port = 1001
    ServerType = stNonBlocking
    OnClientRead = ServerSocket1ClientRead
    Left = 34
    Top = 32
  end
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 99
    Top = 30
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 250
    OnTimer = Timer1Timer
    Left = 47
    Top = 96
  end
end
