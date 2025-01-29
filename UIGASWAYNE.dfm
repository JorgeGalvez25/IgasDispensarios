object ogcvdispensarios_wayne: Togcvdispensarios_wayne
  OldCreateOrder = False
  OnDestroy = ServiceDestroy
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStop = ServiceStop
  Left = 326
  Top = 392
  Height = 231
  Width = 344
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
    Interval = 250
    OnTimer = Timer1Timer
    Left = 47
    Top = 96
  end
end
