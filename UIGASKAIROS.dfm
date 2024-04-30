object ogcvdispensarios_kairos: Togcvdispensarios_kairos
  OldCreateOrder = False
  DisplayName = 'OpenGas Dispensarios'
  OnExecute = ServiceExecute
  Left = 441
  Top = 302
  Height = 164
  Width = 224
  object ServerSocket1: TServerSocket
    Active = False
    Port = 1001
    ServerType = stNonBlocking
    OnClientRead = ServerSocket1ClientRead
    Left = 24
    Top = 22
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 280
    OnTimer = Timer1Timer
    Left = 144
    Top = 20
  end
  object pSerial: TApdComPort
    ComNumber = 1
    Baud = 5700
    Parity = pEven
    Tracing = tlOn
    TraceSize = 15000
    TraceName = 'APRO.TRC'
    TraceAllHex = True
    LogName = 'APRO.LOG'
    OnTriggerAvail = pSerialTriggerAvail
    Left = 81
    Top = 64
  end
end
