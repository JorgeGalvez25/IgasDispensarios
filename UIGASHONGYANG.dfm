object ogcvdispensarios_hongyang: Togcvdispensarios_hongyang
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 331
  Top = 124
  Height = 192
  Width = 251
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 133
    Top = 36
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 40
    OnTimer = Timer1Timer
    Left = 48
    Top = 96
  end
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 50
    Top = 24
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 112
    Top = 95
  end
end
