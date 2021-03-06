unit passwordman;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

  TPasswordManager = class;

  { TPasswordManagerAccount }

  TPasswordManagerAccount = class(TObject)
    private
      FOwner       : TPasswordManager;
      FEnabled     : Boolean;
      FUsername    : String;
      FPassword    : String;
      FAdmin       : Boolean;
      FLastActive  : TDateTime;
      FDescription : String;
      FParams      : TStrings;
      procedure SetAdmin(AValue: Boolean);
      procedure SetDescription(AValue: String);
      procedure SetEnabled(AValue: Boolean);
      procedure SetLastActive(AValue: TDateTime);
      procedure SetParams(AValue: TStrings);
      procedure SetPassword(AValue: String);
      procedure SetUsername(AValue: String);
      //
      procedure LoadFromStream(Stream: TStream);
      procedure SaveToStream(Stream: TStream);
    public
      constructor Create(AOwner: TPasswordManager);
      destructor Destroy; override;
      //
      procedure Modify; // Modify must be called when Params is changed.
      //
      property Owner: TPasswordManager read FOwner;
      property Enabled: Boolean read FEnabled write SetEnabled;
      property Admin: Boolean read FAdmin write SetAdmin;
      property Username: String read FUsername write SetUsername;
      property Password: String read FPassword write SetPassword;
      property LastActive: TDateTime read FLastActive write SetLastActive;
      property Description: String read FDescription write SetDescription;
      property Params: TStrings read FParams write SetParams;
  end;

  TPasswordManager = class(TPersistent)
    private
      FList: TList;
      FModified: Boolean;
      function GetBase64: String;
      function GetCount: Integer;
      function GetItem(Index: Integer): TPasswordManagerAccount;
      procedure SetBase64(AValue: String);
    public
      constructor Create;
      destructor Destroy; override;
      //
      procedure Clear;
      function Find(Username: String): TPasswordManagerAccount;
      function Remove(Username: String): Boolean;
      function Authenticate(Username,Password: String): Boolean;
      //
      procedure LoadFromStream(Stream: TStream);
      procedure SaveToStream(Stream: TStream);
      procedure LoadFromFile(Filename: String);
      procedure SaveToFile(Filename: String);
      //
      property Count: Integer read GetCount;
      property Items[Index: Integer]: TPasswordManagerAccount read GetItem; default;
      property Modified: Boolean read FModified write FModified;
      property AsBase64: String read GetBase64 write SetBase64;
  end;

implementation

uses
  StreamUtils, Base64;

{ TPasswordManager }

function TPasswordManager.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TPasswordManager.GetItem(Index: Integer): TPasswordManagerAccount;
begin
  Result := TPasswordManagerAccount(FList[Index]);
end;

function TPasswordManager.GetBase64: String;
var
  M: TStringStream;
  S: TBase64EncodingStream;
begin
  Result := '';
  M := TStringStream.Create(Result);
  try
    S := TBase64EncodingStream.Create(M);
    try
      SaveToStream(S);
      S.Flush;
      Result := M.DataString;
    finally
      S.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure TPasswordManager.SetBase64(AValue: String);
var
  M: TStringStream;
  S: TBase64DecodingStream;
begin
  M := TStringStream.Create(AValue);
  try
    S := TBase64DecodingStream.Create(M);
    try
      LoadFromStream(S);
    finally
      S.Free;
    end;
  finally
    M.Free;
  end;
end;

constructor TPasswordManager.Create;
begin
  FList := TList.Create;
end;

destructor TPasswordManager.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TPasswordManager.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    with Items[I] do
      begin
        Items[I].FOwner := nil;
        Items[I].Free;
      end;
  FList.Clear;
end;

function TPasswordManager.Find(Username: String): TPasswordManagerAccount;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    begin
      Result := Items[I];
      if CompareText(Result.Username,Username) = 0 then
        Exit;
    end;
  Result := nil;
end;

function TPasswordManager.Remove(Username: String): Boolean;
var
  O: TPasswordManagerAccount;
begin
  O := Find(Username);
  Result := O <> nil;
  if Result then
    O.Destroy;
end;

function TPasswordManager.Authenticate(Username, Password: String): Boolean;
var
  Account: TPasswordManagerAccount;
begin
  Account := Find(Username);
  if Assigned(Account) then
    Result := Account.Password = Password
  else
    Result := False;
end;

procedure TPasswordManager.LoadFromStream(Stream: TStream);
var
  I,C: Integer;
  O: TPasswordManagerAccount;
begin
  if Assigned(Stream) then
    begin
      Clear;
      if Stream.Position <> 0 then
        Stream.Position := 0;
      if Stream.Read(C,SizeOf(C)) = SizeOf(C) then
        begin
          FList.Capacity := C;
          for I := 0 to C - 1 do
            begin
              O := TPasswordManagerAccount.Create(Self);
              O.LoadFromStream(Stream);
            end;
        end;
      FModified := False;
    end;
end;

procedure TPasswordManager.SaveToStream(Stream: TStream);
var
  I: Integer;
begin
  if Assigned(Stream) then
    begin
      Stream.Size := 0;
      I := FList.Count;
      Stream.Write(I,SizeOf(I));
      for I := 0 to FList.Count - 1 do
        Items[I].SaveToStream(Stream);
      FModified := False;
    end;
end;

procedure TPasswordManager.LoadFromFile(Filename: String);
var
  S: TFileStream;
begin
  S := TFileStream.Create(Filename,fmOpenRead);
  try
    LoadFromStream(S);
  finally
    S.Free;
  end;
end;

procedure TPasswordManager.SaveToFile(Filename: String);
var
  S: TFileStream;
begin
  S := TFileStream.Create(Filename,fmCreate);
  try
    SaveToStream(S);
  finally
    S.Free;
  end;
end;

{ TPasswordManagerAccount }

procedure TPasswordManagerAccount.SetDescription(AValue: String);
begin
  if FDescription=AValue then Exit;
  FDescription:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.SetAdmin(AValue: Boolean);
begin
  if FAdmin=AValue then Exit;
  FAdmin:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.SetEnabled(AValue: Boolean);
begin
  if FEnabled=AValue then Exit;
  FEnabled:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.SetLastActive(AValue: TDateTime);
begin
  if FLastActive=AValue then Exit;
  FLastActive:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.SetParams(AValue: TStrings);
begin
  if FParams=AValue then Exit;
  FParams.Clear;
  if Assigned(AValue) then
    FParams.Assign(AValue);
  Modify;
end;

procedure TPasswordManagerAccount.SetPassword(AValue: String);
begin
  if FPassword=AValue then Exit;
  FPassword:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.SetUsername(AValue: String);
begin
  if FUsername=AValue then Exit;
  FUsername:=AValue;
  Modify;
end;

procedure TPasswordManagerAccount.LoadFromStream(Stream: TStream);
begin
  if Assigned(Stream) then
    begin
      Stream.Read(FEnabled,SizeOf(FEnabled));
      Stream.Read(FAdmin,SizeOf(Admin));
      FUsername := LoadStringFromStreamByte(Stream);
      FPassword := LoadStringFromStreamByte(Stream);
      FDescription := LoadStringFromStreamWord(Stream);
      Stream.Read(FLastActive,SizeOf(FLastActive));
      LoadStringsFromStream(FParams,Stream);
    end;
end;

procedure TPasswordManagerAccount.SaveToStream(Stream: TStream);
begin
  if Assigned(Stream) then
    begin
      Stream.Write(FEnabled,SizeOf(FEnabled));
      Stream.Write(FAdmin,SizeOf(Admin));
      SaveStringToStreamByte(FUsername,Stream);
      SaveStringToStreamByte(FPassword,Stream);
      SaveStringToStreamWord(FDescription,Stream);
      Stream.Write(FLastActive,SizeOf(FLastActive));
      SaveStringsToStream(FParams,Stream);
    end;
end;

procedure TPasswordManagerAccount.Modify;
begin
  if Assigned(FOwner) then
    FOwner.FModified := True;
end;

constructor TPasswordManagerAccount.Create(AOwner: TPasswordManager);
begin
  inherited Create;
  FOwner := AOwner;
  if Assigned(FOwner) then
    FOwner.FList.Add(Self);
  FParams := TStringList.Create;
end;

destructor TPasswordManagerAccount.Destroy;
begin
  if Assigned(FOwner) then
    FOwner.FList.Remove(Self);
  FParams.Free;
  inherited Destroy;
end;

end.

