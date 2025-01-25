program HMH;

{$APPTYPE GUI}
{$R *.res}

uses
  System.SysUtils,
  Windows;

begin
  try
    MessageBox(0, 'This is Handmade Hero.', 'Handmade Hero',
      MB_OK or MB_ICONINFORMATION);
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;

end.
