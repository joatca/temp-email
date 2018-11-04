module TempEmail

  record Data, verb : Symbol, value : String
  record Response, code : Int32, message : String, info : String = ""
  #alias Data = Tuple(Symbol, String)
  #alias Response = Tuple(Int32, String)
  alias Msg = TCPSocket | Data | Response | Nil

end
