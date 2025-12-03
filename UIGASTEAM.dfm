object ogcvdispensarios_team: Togcvdispensarios_team
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 241
  Top = 2
  Height = 203
  Width = 213
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 125
    Top = 31
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 250
    OnTimer = Timer1Timer
    Left = 47
    Top = 96
  end
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 56
    Top = 28
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 125
    Top = 109
  end
end
