object ogcvdispensarios_bennett: Togcvdispensarios_bennett
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 1119
  Top = 349
  Height = 194
  Width = 290
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
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 158
    Top = 97
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 168
    Top = 36
  end
end
