program HMH;

{$APPTYPE GUI}
{$R *.res}
{$POINTERMATH ON}

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Messages;

var
  Running: Boolean;
  BmpInfo: TBitmapInfo;
  BmpMemory: Pointer = nil;
  BitmapWidth, BitmapHeight: Integer;

procedure DebugLog(const Msg: string);
begin
  {$IFDEF DEBUG}
  OutputDebugString(PChar('DEBUG: ' + Msg + sLineBreak));
  {$ENDIF}
end;

function GetClientRectangle(Handle: HWND): TRect;
var
  Rect: TRect;
  Succesful: LongBool;
begin
  Succesful := GetClientRect(Handle, Rect);
  if not Succesful then
    OutputDebugString('GetClientRectangle: Couldn''t retrieve client size');

  Result := Rect;
end;

procedure Win32ResizeDIBSection(Width, Height: Integer);
const
  BytesPerPixel = 4;
begin
  if BmpMemory <> nil then
    VirtualFree(BmpMemory, 0, MEM_RELEASE);

  BitmapWidth := Width;
  BitmapHeight := Height;

  ZeroMemory(@BmpInfo, SizeOf(BmpInfo));
  with BmpInfo.BmiHeader do
  begin
    biSize := SizeOf(BmpInfo.bmiHeader);
    biWidth := BitmapWidth;
    biHeight := -BitmapHeight;
    biPlanes := 1;
    biBitCount := 32;
    biCompression := BI_RGB;
  end;

  BmpMemory := VirtualAlloc(nil, BitmapWidth * BitmapHeight * BytesPerPixel,
    MEM_COMMIT, PAGE_READWRITE);

  var Pitch := Width * BytesPerPixel;

  var Row := PByte(BmpMemory);
  for var Y := 0 to Pred(BitmapHeight) do
  begin
    var Pixel := PByte(Row);
    for var X := 0 to Pred(BitmapWidth) do
    begin
      Pixel^ := X and $FF;
      Inc(Pixel);

      Pixel^ := Y and $FF;
      Inc(Pixel);

      Pixel^ := $FF;
      Inc(Pixel);

      Pixel^ := $00;
      Inc(Pixel);
    end;
    Row := Row + Pitch;
  end;

  DebugLog(Format('DIB Section created (%dx%d).', [Width, Height]));
end;

procedure Win32UpdateWindow(DeviceContext: HDC; WindowRect: TRect; Top, Left,
  Width, Height: Integer);
var
  WindowWidth, WindowHeight: Integer;
begin
  WindowWidth := WindowRect.Right - WindowRect.Left;
  WindowHeight := WindowRect.Bottom - WindowRect.Top;
  if BmpMemory <> nil then
    StretchDIBits(DeviceContext, 0, 0, BitmapWidth, BitmapHeight, 0, 0,
      WindowWidth, WindowHeight, BmpMemory, BmpInfo, DIB_RGB_COLORS, SRCCOPY)
  else
    DebugLog('Win32UpdateWindow: Bitmap memory is nil. Update skipped.');
end;

function WindowProc(Window: HWND; Msg: UINT; WParam: WParam; LParam: LParam):
  LRESULT; stdcall;
var
  DeviceContext: HDC;
  Paint: TPaintStruct;
  Top, Left, Height, Width: FixedInt;
begin
  case Msg of
    WM_SIZE:
      begin
        var Rect := GetClientRectangle(Window);

        Width := Rect.Right - Rect.Left;
        Height := Rect.Bottom - Rect.Top;

        Win32ResizeDIBSection(Width, Height);

        DebugLog('WM_SIZE' + sLineBreak);
        Result := 0;
      end;

    WM_DESTROY:
      begin
        DebugLog('WM_DESTROY' + sLineBreak);
        Running := False;
        PostQuitMessage(0);
        Result := 0;
      end;

    WM_CLOSE:
      begin
        DebugLog('WM_CLOSE' + sLineBreak);
        DestroyWindow(Window);
        Result := 0;
      end;

    WM_PAINT:
      begin
        DeviceContext := BeginPaint(Window, Paint);

        try
          Top := Paint.RCPaint.Top;
          Left := Paint.RCPaint.Left;
          Height := Paint.RCPaint.Bottom - Paint.RCPaint.Top;
          Width := Paint.RCPaint.Right - Paint.RCPaint.Left;

          var ClientRect := GetClientRectangle(Window);

          Win32UpdateWindow(DeviceContext, ClientRect, Top, Left, Width, Height);
        finally
          EndPaint(Window, Paint);
        end;
      end;

    WM_ACTIVATEAPP:
      begin
        if WParam <> 0 then
          DebugLog('App activated' + sLineBreak)
        else
          DebugLog('App deactivated' + sLineBreak);

        Result := 0;
      end;
  else
    Result := DefWindowProc(Window, Msg, WParam, LParam);
  end;
end;

var
  WindowClass: TWndClassEx;

begin
  var InstanceHandle := GetModuleHandle(nil);

  ZeroMemory(@WindowClass, SizeOf(WindowClass));

  with WindowClass do
  begin
    cbSize := SizeOf(WindowClass);
    Style := CS_HREDRAW or CS_VREDRAW or CS_OWNDC;
    lpfnWndProc := @WindowProc;
    HInstance := InstanceHandle;
    lpszClassName := 'HandmadeHeroWndClass';
  end;

  if RegisterClassEx(WindowClass) = 0 then
  begin
    MessageBox(0, 'Failed to register window class!', 'Error', MB_ICONERROR);
    Exit;
  end;

  var WindowHandle := CreateWindowEx(0, WindowClass.lpszClassName,
    'Handmade Hero', WS_OVERLAPPEDWINDOW or WS_VISIBLE, CW_USEDEFAULT,
    CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, InstanceHandle, nil);

  if WindowHandle = 0 then
  begin
    MessageBox(0, 'Failed to create window!', 'Error', MB_ICONERROR);
    Exit;
  end;

  Running := True;

  var Msg: TMsg;
  while Running do
  begin
    var HasQuit := not GetMessage(Msg, 0, 0, 0);
    if HasQuit then
      Break;

    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

  if BmpMemory <> nil then
    VirtualFree(BmpMemory, 0, MEM_RELEASE);
end.

