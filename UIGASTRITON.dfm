object ogcvdispensarios_triton: Togcvdispensarios_triton
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 442
  Top = 363
  Height = 197
  Width = 219
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 58
    Top = 32
  end
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 134
    Top = 34
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 150
    OnTimer = Timer1Timer
    Left = 40
    Top = 93
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 118
    Top = 104
  end
end
