program HMH;

{$APPTYPE GUI}
{$R *.res}

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Messages;

var
  Running: Boolean;

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
        OutputDebugString('WM_SIZE' + sLineBreak);
        Result := 0;
      end;

    WM_DESTROY:
      begin
        OutputDebugString('WM_DESTROY' + sLineBreak);
        Running := False;
        PostQuitMessage(0);
        Result := 0;
      end;

    WM_CLOSE:
      begin
        OutputDebugString('WM_CLOSE' + sLineBreak);
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

          PatBlt(DeviceContext, Top, Left, Width, Height, BLACKNESS);
        finally
          EndPaint(Window, Paint);
        end;
      end;

    WM_ACTIVATEAPP:
      begin
        if WParam <> 0 then
          OutputDebugString('App Activated' + sLineBreak)
        else
          OutputDebugString('App Deactivated' + sLineBreak);
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
end.

