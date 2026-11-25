defmodule SatOpsWeb.CsvTest do
  use ExUnit.Case, async: true
  alias SatOpsWeb.ImportController

  test "parses quoted values and integer satoshis" do
    csv = "source_record_id,kind,account_ref,amount_sats,txid,vout,status\n1,deposit,\"c,1\",1000,aa,0,credited\n"
    assert {:ok, [%{"account_ref" => "c,1", "amount_sats" => 1000, "vout" => 0}]} = ImportController.parse(csv)
  end

  test "rejects decimal amounts" do
    assert {:error, msg} = ImportController.parse("source_record_id,amount_sats\n1,0.5\n")
    assert msg =~ "satoshis"
  end
end
