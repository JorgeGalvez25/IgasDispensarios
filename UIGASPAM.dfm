object ogcvdispensarios_pam: Togcvdispensarios_pam
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 276
  Top = 75
  Height = 203
  Width = 279
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
