object ogcvdispensarios_gilbarco2W: Togcvdispensarios_gilbarco2W
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 301
  Top = 204
  Height = 204
  Width = 173
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
    Interval = 50
    OnTimer = Timer1Timer
    Left = 22
    Top = 93
  end
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Host = '127.0.0.1'
    Port = 8585
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 24
    Top = 33
  end
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 88
    Top = 93
  end
end
