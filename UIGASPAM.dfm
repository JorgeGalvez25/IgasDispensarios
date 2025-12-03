object ogcvdispensarios_pam: Togcvdispensarios_pam
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 276
  Top = 75
  Height = 203
  Width = 279
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
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 168
    Top = 35
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
end
