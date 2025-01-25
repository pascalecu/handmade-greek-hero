program HMH;

{$APPTYPE GUI}
{$R *.res}

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Messages;

var
  Running: Boolean;
  BmpInfo: TBitmapInfo;
  BitmapMemory: Pointer = nil;
  BitmapHandle: HBITMAP = 0;
  BitmapDeviceContext: HDC = 0;

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
begin
  if BitmapHandle <> 0 then
  begin
    DeleteObject(BitmapHandle);
    BitmapHandle := 0;
  end;

  if BitmapDeviceContext <> 0 then
  begin
    SelectObject(BitmapDeviceContext, 0);
    DeleteDC(BitmapDeviceContext);
    BitmapDeviceContext := 0;
  end;

  BitmapDeviceContext := CreateCompatibleDC(0);
  if BitmapDeviceContext = 0 then
  begin
    DebugLog('Win32ResizeDIBSection: Failed to create compatible DC.');
    Exit;
  end;

  ZeroMemory(@BmpInfo, SizeOf(BmpInfo));
  with BmpInfo.BmiHeader do
  begin
    biSize := SizeOf(BmpInfo.bmiHeader);
    biWidth := Width;
    biHeight := -Height;
    biPlanes := 1;
    biBitCount := 32;
    biCompression := BI_RGB;
  end;

  BitmapMemory := nil;
  BitmapHandle := CreateDIBSection(BitmapDeviceContext, BmpInfo, DIB_RGB_COLORS,
    BitmapMemory, 0, 0);

  if BitmapHandle = 0 then
  begin
    DebugLog('Win32ResizeDIBSection: Failed to create DIB section.');
    DeleteDC(BitmapDeviceContext);
    BitmapDeviceContext := 0;
    Exit;
  end;

  DebugLog(Format('DIB Section created (%dx%d).', [Width, Height]));
end;

procedure Win32UpdateWindow(DeviceContext: HDC; Top, Left, Width, Height: Integer);
begin
  if BitmapMemory <> nil then
    StretchDIBits(DeviceContext, Top, Left, Width, Height, 0, 0, Width, Height,
      BitmapMemory, BmpInfo, DIB_RGB_COLORS, SRCCOPY)
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

          Win32UpdateWindow(DeviceContext, Top, Left, Width, Height);
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

  if BitmapHandle <> 0 then
    DeleteObject(BitmapHandle);

  if BitmapDeviceContext <> 0 then
    DeleteDC(BitmapDeviceContext);

  BitmapMemory := nil;
  BitmapHandle := 0;
  BitmapDeviceContext := 0;

end.

