{**************************************************************************************************}
{                                                                                                  }
{  CRCs, Version 1.0                                                                               }
{                                                                                                  }
{  The contents of this file are subject to the Y Library Public License Version 1.0 (the          }
{  "License"); you may not use this file except in compliance with the License. You may obtain a   }
{  copy of the License at http://delphi.pjh2.de/                                                   }
{                                                                                                  }
{  Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF  }
{  ANY KIND, either express or implied. See the License for the specific language governing        }
{  rights and limitations under the License.                                                       }
{                                                                                                  }
{  The Original Code is: CRCs.pas.                                                                 }
{  The Initial Developer of the Original Code is Peter J. Haas (libs@pjh2.de). Portions created    }
{  by Peter J. Haas are Copyright (C) 2001-2005 Peter J. Haas. All Rights Reserved.                }
{                                                                                                  }
{  Contributor(s):                                                                                 }
{                                                                                                  }
{  You may retrieve the latest version of this file at the homepage of Peter J. Haas, located at   }
{  http://delphi.pjh2.de/                                                                          }
{                                                                                                  }
{ Source:                                                                                          }
{   ftp://ftp.rocksoft.com/papers/crc_v3.txt                                                       }
{                                                                                                  }
{**************************************************************************************************}
{                                                                                                  }
{ Comments:                                                                                        }
{   This library is consider for experiments with different CRC calculations.                      }
{   The functions are not optimized for performance.                                               }
{                                                                                                  }
{   You can use CrcCreateSource to create fast source code for a special CRC.                      }
{                                                                                                  }
{**************************************************************************************************}

// For history see end of file

{$ALIGN ON, $BOOLEVAL OFF, $LONGSTRINGS ON, $IOCHECKS ON, $WRITEABLECONST OFF}
{$OVERFLOWCHECKS OFF, $RANGECHECKS OFF, $TYPEDADDRESS ON, $MINENUMSIZE 1}
unit CRCs;

interface
uses
  Windows, SysUtils;

type
  TCRCDescription = record
    Width    : Integer;
    Polynom  : DWord;
    Init     : DWord;
    RefIn    : Boolean;
    RefOut   : Boolean;
    XorOut   : DWord;
  end;

  TCRCHandle = DWord;

  TCRCLookUpTable16 = array[Byte] of Word;
  TCRCLookUpTable32 = array[Byte] of DWord;

// CRC calculation
// Desc: describe the CRC parameters
// DataPtr: Pointer to the byte of block, that will be calculate at first
// DataLen: Length of Data (0: no calculation,
//                          negative values: DataPtr is the end of data block)
function CrcCalc(const Desc: TCRCDescription;
                 DataPtr: Pointer; DataLen: Integer): DWord;


// ****************  Handle based functions  ************************

// Init of calculation
// Desc: describe the CRC parameters
// Result: a handle to the CRC object
function CrcInit(const Desc: TCRCDescription): TCRCHandle;

// Add 1 byte to Checksum
// Handle: handle to the CRC object
// DataPtr: Pointer to the byte
// Result: Success of calculation, False means Handle is not a valid CRC object
function CrcCalcByte(Handle: TCRCHandle; DataPtr: Pointer): Boolean;

// Add a block to Checksum
// Handle: handle to the CRC object
// DataPtr: Pointer to the byte of block, that will be calculate at first
// DataLen: Length of Data (0: no calculation,
//                          negative values: DataPtr is the end of data block)
// Result: Success of calculation, False means Handle is not a valid CRC object
function CrcCalcBlock(Handle: TCRCHandle;
                      var DataPtr: Pointer; DataLen: Integer): Boolean;

// Close the calculation and release the CRC object
// Handle: handle to the CRC object
// CRC: return the Checksum
// Result: Success of calculation, False means Handle is not a valid CRC object
function CrcClose(Handle: TCRCHandle; var CRC: DWord): Boolean;


// ****************  Class for CRC calculation  *********************

type
  TCRC = class(TObject)
  private
    FDescription: TCRCDescription;
    FWidthMask  : DWord;            // mask for all valid bits
    FTopBit     : DWord;            // mask for top bit
    FCRC        : DWord;            // current checksum without finish
  public
    // Init of calculation
    // Desc: describe the CRC parameters
    constructor Create(const Desc: TCRCDescription);

    // Add 1 byte to Checksum
    // DataPtr: Pointer to the byte
    procedure CalcByte(DataPtr: Pointer);

    // Add a block to Checksum
    // DataPtr: Pointer to the byte of block, that will be calculate at first
    // DataLen: Length of Data (0: no calculation,
    //                          negative values: DataPtr is the end of data block)
    procedure CalcBlock(var DataPtr: Pointer; DataLen: Integer);

    // Close the calculation and release the CRC object
    // Result: the Checksum
    function Finish: DWord;
  end;


// ****************  helper functions  ******************************

// Reflect the BitCount least significant bits in Value and return this value
function CrcReflect(Value: DWord; BitCount: Integer): DWord;


// ****************  CRC Lookup Table Generation  *******************

// Calculate a CRC Lookup Table Item
// Desc: describe the CRC parameters
// Index: index in Lookup Table
function CrcMakeLookupTableItem(const Desc: TCRCDescription;
                                Index: Integer): DWord;

// Calculate a 16 Bit CRC Lookup Table
// Desc: describe the CRC parameters
// Table: CRC-Table
// Result: Success, False means the Desc.Width is greater as 16
function CrcMakeLookupTable16(const Desc: TCRCDescription;
                              var Table: TCRCLookUpTable16): Boolean;

// Calculate a 32 Bit CRC Lookup Table
// Desc: describe the CRC parameters
// Table: CRC-Table
// Result: Success, False means the Desc.Width is greater as 32
function CrcMakeLookupTable32(const Desc: TCRCDescription;
                              var Table: TCRCLookUpTable32): Boolean;


// ****************  CRC Lookup Table Calculation  ******************

// CRC calculation with Lookup Table
// Desc: describe the CRC parameters
// Table: CRC Lookup Table
// DataPtr: Pointer to the byte of block, that will be calculate at first
// DataLen: Length of Data (0: no calculation,
//                          negative values: DataPtr is the end of data block)
function CrcCalcLUT32(const Desc: TCRCDescription;
                      const Table: TCRCLookUpTable32;
                      DataPtr: Pointer; DataLen: Integer): DWord;
                      
// same for 16 Bit Lookup Table
function CrcCalcLUT16(const Desc: TCRCDescription;
                      const Table: TCRCLookUpTable16;
                      DataPtr: Pointer; DataLen: Integer): Word;


// ****************  CRC Calculation Source Generation  *************

// Generate Delphi Source for CRC Calculation
// Name: Name for Lookuptable constant and function
// Desc: describe the CRC parameters
// Result: source with CR LF as line separator
//
// Sample:
//   Memo1.Lines.Text := CrcCreateSource('CRC32', CRC32Desc);
//
function CrcCreateSource(Name: String; const Desc: TCRCDescription): String;


// ****************  Know CRC Descriptions  *************************

const
  CRC16Desc : TCRCDescription =
    (Width    : 16;
     Polynom  : $00008005;
     Init     : $00000000;
     RefIn    : True;
     RefOut   : True;
     XorOut   : $00000000);

  CRC16CCITTDesc : TCRCDescription =
    (Width    : 16;
     Polynom  : $00001021;
     Init     : $FFFFFFFF;
     RefIn    : False;
     RefOut   : False;
     XorOut   : $00000000);

  CRC16XModemDesc : TCRCDescription =
    (Width    : 16;
     Polynom  : $00008408;
     Init     : $00000000;
     RefIn    : True;
     RefOut   : True;
     XorOut   : $00000000);

  CRC32Desc : TCRCDescription =
    (Width    : 32;
     Polynom  : $04C11DB7;
     Init     : $FFFFFFFF;
     RefIn    : True;
     RefOut   : True;
     XorOut   : $FFFFFFFF);


implementation

function CrcCalc(const Desc: TCRCDescription;
                 DataPtr: Pointer; DataLen: Integer): DWord;
begin
  with TCRC.Create(Desc) do try
    CalcBlock(DataPtr, DataLen);
    Result := Finish;
  finally
    Free;
  end;
end;

const
  Bitmask : array[0..31] of DWord =
    ($00000001, $00000002, $00000004, $00000008,
     $00000010, $00000020, $00000040, $00000080,
     $00000100, $00000200, $00000400, $00000800,
     $00001000, $00002000, $00004000, $00008000,
     $00010000, $00020000, $00040000, $00080000,
     $00100000, $00200000, $00400000, $00800000,
     $01000000, $02000000, $04000000, $08000000,
     $10000000, $20000000, $40000000, $80000000);

function CrcReflect(Value: DWord; BitCount: Integer): DWord;
var
  i: Integer;
begin
  Result := Value;
  Dec(BitCount);
  for i := 0 to BitCount do
  begin
    if (Value and 1) <> 0 then
      Result := Result or Bitmask[BitCount - i]
    else
      Result := Result and not Bitmask[BitCount - i];
    Value := Value shr 1;
  end;
end;

// object based functions

constructor TCRC.Create(const Desc: TCRCDescription);
begin
  FDescription := Desc;
  FCRC := FDescription.Init;
  FWidthMask := (((1 shl FDescription.Width) and $FFFFFFFE) - 1) or 1;
  FTopBit := 1 shl (FDescription.Width - 1);
end;

procedure TCRC.CalcByte(DataPtr: Pointer);
var
  Data: DWord;
  i: Integer;
begin
  Data := PByte(DataPtr)^;
  if FDescription.RefIn then Data := CrcReflect(Data, 8);
  FCRC := FCRC xor (Data shl (FDescription.Width - 8));
  for i := 0 to 7 do
  begin
    if (FCRC and FTopBit) <> 0 then
      FCRC := (FCRC shl 1) xor FDescription.Polynom
    else
      FCRC := FCRC shl 1;
    FCRC := FCRC and FWidthMask;
  end;
end;

procedure TCRC.CalcBlock(var DataPtr: Pointer; DataLen: Integer);
var
  i: Integer;
begin
  for i := 0 to Abs(DataLen) - 1 do
  begin
    CalcByte(DataPtr);
    if DataLen >= 0 then
      Inc(PByte(DataPtr))
    else
      Dec(PByte(DataPtr));
  end;
end;

function TCRC.Finish: DWord;
begin
  if FDescription.RefOut then
    Result := FDescription.XorOut xor CrcReflect(FCRC, FDescription.Width)
  else
    Result := FDescription.XorOut xor FCRC;
end;


// Handle based functions

function CrcInit(const Desc: TCRCDescription): TCRCHandle;
begin
  Result := TCRCHandle(TCRC.Create(Desc));
end;

function CrcCalcByte(Handle: TCRCHandle; DataPtr: Pointer): Boolean;
begin
  Result := TObject(Handle) is TCRC;
  if Result then TCRC(Handle).CalcByte(DataPtr);
end;

function CrcCalcBlock(Handle: TCRCHandle; var DataPtr: Pointer; DataLen: Integer): Boolean;
begin
  Result := TObject(Handle) is TCRC;
  if Result then TCRC(Handle).CalcBlock(DataPtr, DataLen);
end;

function CrcClose(Handle: TCRCHandle; var CRC: DWord): Boolean;
begin
  Result := TObject(Handle) is TCRC;
  if Result then begin
    CRC := TCRC(Handle).Finish;
    TCRC(Handle).Free;
  end;
end;


// ****************  CRC Lookup Table Generation  *******************

function CrcMakeLookupTableItem(const Desc: TCRCDescription;
                                Index: Integer): DWord;
var
  i: Integer;
  WidthMask: DWord;
  TopBit: DWord;
begin
  with Desc do
  begin
    WidthMask := (((1 shl Width) and $FFFFFFFE) - 1) or 1;
    TopBit := 1 shl (Width - 1);
    if RefIn then
      Result := CrcReflect(Index, 8)
    else
      Result := Index;
    Result := Result shl (Width - 8);
    for i := 0 to 7 do
    begin
      if (Result and TopBit) <> 0 then
        Result := (Result shl 1) xor Polynom
      else
        Result := Result shl 1;
    end;
    if RefIn then
      Result := CrcReflect(Result, Width);
    Result := Result and WidthMask;
  end;
end;

function CrcMakeLookupTable16(const Desc: TCRCDescription;
                              var Table: TCRCLookUpTable16): Boolean;
var
  i: Integer;
begin
  Result := Desc.Width <= 16;
  if not Result then Exit;
  for i := 0 to 255 do
    Table[i] := CrcMakeLookupTableItem(Desc, i);
end;

function CrcMakeLookupTable32(const Desc: TCRCDescription;
                              var Table: TCRCLookUpTable32): Boolean;
var
  i: Integer;
begin
  Result := Desc.Width <= 32;
  if not Result then Exit;
  for i := 0 to 255 do
    Table[i] := CrcMakeLookupTableItem(Desc, i);
end;

procedure CrcCalcByteLUT32Normal(const Table: TCRCLookUpTable32;
                                 Width: Integer;
                                 DataPtr: Pointer;
                                 var CRC: DWord);
begin
  CRC := Table[Byte((CRC shr (Width - 8)) xor PByte(DataPtr)^)] xor (CRC shl 8);
end;

procedure CrcCalcByteLUT32Reflected(const Table: TCRCLookUpTable32;
                                    Width: Integer;
                                    DataPtr: Pointer;
                                    var CRC: DWord);
begin
  CRC := Table[Byte(CRC xor PByte(DataPtr)^)] xor ((CRC shr 8) and ((1 shl (Width - 8)) - 1));
end;

procedure CrcCalcByteLUT16Normal(const Table: TCRCLookUpTable16;
                                 Width: Integer;
                                 DataPtr: Pointer;
                                 var CRC: Word);
begin
  CRC := Table[Byte((CRC shr (Width - 8)) xor PByte(DataPtr)^)] xor (CRC shl 8);
end;

procedure CrcCalcByteLUT16Reflected(const Table: TCRCLookUpTable16;
                                    Width: Integer;
                                    DataPtr: Pointer;
                                    var CRC: Word);
begin
  CRC := Table[Byte(CRC xor PByte(DataPtr)^)] xor ((CRC shr 8) and ((1 shr (Width - 8)) - 1));
end;

function CrcCalcLUT32(const Desc: TCRCDescription;
                      const Table: TCRCLookUpTable32;
                      DataPtr: Pointer; DataLen: Integer): DWord;
var
  i : Integer;
begin
  Result := Desc.Init;
  if Desc.RefIn then
  begin
    for i := 0 to Abs(DataLen) - 1 do
    begin
      CrcCalcByteLUT32Reflected(Table, Desc.Width, DataPtr, Result);
      if DataLen >= 0 then
        Inc(PByte(DataPtr))
      else
        Dec(PByte(DataPtr));
    end;
  end
  else
  begin
    for i := 0 to Abs(DataLen) - 1 do
    begin
      CrcCalcByteLUT32Normal(Table, Desc.Width, DataPtr, Result);
      if DataLen >= 0 then
        Inc(PByte(DataPtr))
      else
        Dec(PByte(DataPtr));
    end;
  end;
  if Desc.RefOut then
    Result := Result xor CRCReflect(Desc.XorOut, Desc.Width)
  else
    Result := Result xor Desc.XorOut;
end;

function CrcCalcLUT16(const Desc: TCRCDescription;
                      const Table: TCRCLookUpTable16;
                      DataPtr: Pointer; DataLen: Integer): Word;
var
  i : Integer;
begin
  Result := Desc.Init;
  if Desc.RefIn then
  begin
    for i := 0 to Abs(DataLen) - 1 do
    begin
      CrcCalcByteLUT16Reflected(Table, Desc.Width, DataPtr, Result);
      if DataLen >= 0 then
        Inc(PByte(DataPtr))
      else
        Dec(PByte(DataPtr));
    end;
  end
  else
  begin
    for i := 0 to Abs(DataLen) - 1 do
    begin
      CrcCalcByteLUT16Normal(Table, Desc.Width, DataPtr, Result);
      if DataLen >= 0 then
        Inc(PByte(DataPtr))
      else
        Dec(PByte(DataPtr));
    end;
  end;
  if Desc.RefOut then
    Result := Result xor CRCReflect(Desc.XorOut, Desc.Width)
  else
    Result := Result xor Desc.XorOut;
end;

function CrcCreateSource(Name: String; const Desc: TCRCDescription): String;
const
  CRLF = #$0D#$0A;
var
  Table: TCRCLookUpTable32;
  Line: String;
  Line2: String;
  x, y: Integer;
  Value: DWord;
  ValueMask: DWord;
  VarWidth: Integer;
  VarSize: Integer;
  LineCount: Integer;
  ColCount: Integer;

function WidthToCardinalString(Width: Integer): String;
begin
  case Width of
    0..8 : Result := 'Byte';
    9..16 : Result :=  'Word';
  else
    Result := 'DWord';
  end;
end;

function WidthToSize(Width: Integer): Integer;
begin
  case Width of
    0..8 : Result := 8;
    9..16 : Result := 16;
  else
    Result := 32;
  end;
end;

procedure AddLine(const Line: String);
begin
  Result := Result + Line + CRLF;
end;

begin
  Result := '';
  if not (Desc.Width in [1..32]) then Exit;
  if Length(Name) = 0 then Name := 'CRC';

  VarWidth := WidthToSize(Desc.Width);
  VarSize := VarWidth div 4;
  ValueMask := (((1 shl Desc.Width) and $FFFFFFFE) - 1) or 1;

  Result := 'const' + CRLF;
  // Write Lookup Table
  CrcMakeLookupTable32(Desc, Table);
  AddLine(Format('  %s_LUT : array[Byte] of %s =',
                 [Name, WidthToCardinalString(Desc.Width)]));
  LineCount := VarWidth * 2;
  ColCount := 256 div LineCount;
  for y := 0 to LineCount - 1 do
  begin
    if y = 0 then Line := '    ('
             else Line := '     ';
    for x := 0 to ColCount - 1 do
    begin
      if x > 0 then
        Line := Line + ', ';
      Line := Format('%s$%.*x',
                     [Line, VarSize, Table[y * ColCount + x] and ValueMask]);
    end;
    if y < LineCount - 1 then
      Line := Line + ','
    else
      Line := Line + ');';
    AddLine(Line);
  end;

  // Write Source
  AddLine('');

  AddLine(Format('function %sCalc(DataPtr: Pointer; DataLen: Integer): %s;',
                 [Name, WidthToCardinalString(Desc.Width)]));
  AddLine('var');
  AddLine('  i: Integer;');
  AddLine('begin');
  AddLine('  // Init');
  AddLine(Format('  Result := $%.*x;', [VarSize, Desc.Init and ValueMask]));

  AddLine('  // Calculate CRC');
  AddLine('  for i := 0 to DataLen - 1 do');
  AddLine('  begin');
  if Desc.RefIn then  // reflected version
  begin
    if Desc.Width > 8 then
      Line := Format(' xor'+ CRLF+ '              ((Result shr 8) and $%.*x)',
                     [VarSize, (1 shl (Desc.Width - 8)) - 1])
    else
      Line := '';
    AddLine(Format('    Result := %s_LUT[Byte(Result xor PByte(DataPtr)^)]%s;',
                   [Name, Line]));
  end
  else  // normal version
  begin
    if Desc.Width > 8 then
    begin
      Line := Format('(Result shr %d)', [Desc.Width - 8]);
      Line2 := ' xor' + CRLF + '              (Result shl 8)';
    end
    else
    begin
      Line := 'Result';
      Line2 := '';
    end;
    AddLine(Format('    Result := %s_LUT[Byte(%s xor PByte(DataPtr)^)]%s;',
                   [Name, Line, Line2]));
  end;
  AddLine('    Inc(PByte(DataPtr));');
  AddLine('  end;');

  if (Desc.XorOut and ValueMask) <> 0 then
  begin
    if Desc.RefOut then
      Value := CRCReflect(Desc.XorOut, Desc.Width)
    else
      Value := Desc.XorOut;
    AddLine('  // Finish');
    AddLine(Format('  Result := Result xor $%.*x;',
                   [VarSize, Value and ValueMask]));
  end;

  // Mask the valid bits, if needed
  if VarWidth > Desc.Width then
    AddLine(Format('  Result := Result and $%.*x;',
                   [VarSize, ValueMask]));
  AddLine('end;');
end;

// *******************************************************************************************

//  History:
//  2005-02-23, Peter J. Haas
//   - new license
//
//  2001-06-04, Peter J. Haas
//   - first version

end.
