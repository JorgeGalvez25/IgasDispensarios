object ogcvdispensarios_wayne: Togcvdispensarios_wayne
  OldCreateOrder = False
  OnDestroy = ServiceDestroy
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStop = ServiceStop
  Left = 326
  Top = 392
  Height = 225
  Width = 275
  object pSerial: TApdComPort
    TraceName = 'APRO.TRC'
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 134
    Top = 34
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 250
    OnTimer = Timer1Timer
    Left = 40
    Top = 94
  end
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
  object Timer2: TTimer
    Interval = 200
    OnTimer = Timer2Timer
    Left = 118
    Top = 104
  end
end
