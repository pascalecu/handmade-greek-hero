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

function AllocateMemory(Size: UInt64): Pointer;
begin
  if Size = 0 then
    Exit(nil);

  Result := VirtualAlloc(nil, Size, MEM_COMMIT, PAGE_READWRITE);
  if Result = nil then
  begin
    DebugLog('Error: Failed to allocate memory.');
    MessageBox(0, 'Failed to allocate memory. The application will terminate.',
      'Memory Allocation Error', MB_ICONERROR);
    Halt(1);
  end;
end;

procedure FreeMemory(MemPtr: Pointer);
begin
  if MemPtr <> nil then
    VirtualFree(MemPtr, 0, MEM_RELEASE);
end;

function GetClientRectangle(Handle: hwnd): TRect;
var
  Rect: TRect;
begin
  if not GetClientRect(Handle, Rect) then
    OutputDebugString('GetClientRectangle: Couldn''t retrieve client size');

  Result := Rect;
end;

procedure Win32ResizeDIBSection(Width, Height: Integer);
const
  BytesPerPixel = 4;
begin
  FreeMemory(BmpMemory);

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

  BmpMemory := AllocateMemory(BitmapWidth * BitmapHeight * BytesPerPixel);

  var Pitch := Width * BytesPerPixel;

  var Row := PByte(BmpMemory);
  for var Y := 0 to Pred(BitmapHeight) do
  begin
    var Pixel := Row;
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
    Inc(Row, Pitch);
  end;

  DebugLog(Format('DIB Section created (%dx%d).', [Width, Height]));
end;

procedure Win32ResizeBitmapIfNeeded(NewWidth, NewHeight: Integer);
const
  BytesPerPixel = 4;
var
  NewMemory: Pointer;
begin
  if (BitmapWidth <> NewWidth) or (BitmapHeight <> NewHeight) then
  begin
    FreeMemory(BmpMemory);

    BitmapWidth := NewWidth;
    BitmapHeight := NewHeight;

    NewMemory := AllocateMemory(NewWidth * NewHeight * BytesPerPixel);

    BmpMemory := NewMemory;

    DebugLog(Format('Win32ResizeBitmapIfNeeded: Bitmap resized to %dx%d.', [NewWidth,
      NewHeight]));
  end;
end;

procedure Win32UpdateWindow(DeviceContext: HDC; ClientRect: TRect; Top, Left,
  Width, Height: Integer);
var
  ClientWidth, ClientHeight: Integer;
begin
  ClientWidth := ClientRect.Right - ClientRect.Left;
  ClientHeight := ClientRect.Bottom - ClientRect.Top;

  Win32ResizeBitmapIfNeeded(ClientWidth, ClientHeight);

  if (ClientWidth <= 0) or (ClientHeight <= 0) then
  begin
    DebugLog('Win32UpdateWindow: Invalid window size. Update skipped.');
    Exit;
  end;

  if BmpMemory = nil then
  begin
    DebugLog('Win32UpdateWindow: Bitmap memory is nil. Update skipped.');
    Exit;
  end;

  DebugLog(Format('Updating window to (%dx%d) from bitmap (%dx%d).', [ClientWidth,
    ClientHeight, BitmapWidth, BitmapHeight]));

  StretchDIBits(DeviceContext, 0, 0, ClientWidth, ClientHeight, 0, 0,
    BitmapWidth, BitmapHeight, BmpMemory, BmpInfo, DIB_RGB_COLORS, SRCCOPY);
end;

function WindowProc(Window: hwnd; Msg: UINT; WParam: WParam; LParam: LParam):
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
  &message: TMsg;

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

  while Running do
  begin
    while PeekMessage(&message, 0, 0, 0, PM_REMOVE) do
    begin
      if &message.message = WM_QUIT then
        Running := False;

      TranslateMessage(&message);
      DispatchMessage(&message);
    end;
  end;

  if BmpMemory <> nil then
    VirtualFree(BmpMemory, 0, MEM_RELEASE);
end.

