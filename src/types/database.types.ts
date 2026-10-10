/* Generated database contract from Supabase staging schema mijbpvgxrxjaalimyqgm. */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];
type Table<R> = { Row: R; Insert: Partial<R>; Update: Partial<R>; Relationships: unknown[] };
type PublicTables = {
  audit_logs: Table<{ action:string; actor:string|null; after_data:Json|null; before_data:Json|null; entity_id:string|null; entity_type:string; id:string; occurred_at:string; request_id:string|null }>;
  cod_obligation_allocations: Table<{ cod_obligation_id:string; created_at:string; expected_amount:number; id:string; parcel_id:string }>;
  cod_obligations: Table<{ closed_at:string|null; closed_by:string|null; created_at:string; expected_amount:number; id:string; order_id:string; state:string }>;
  cod_receipts: Table<{ cod_obligation_id:string; expected_amount_snapshot:number; id:string; parcel_id:string; received_amount:number; received_at:string; received_by:string; state:string }>;
  command_idempotency: Table<{ actor_id:string; command_name:string; completed_at:string|null; created_at:string; id:string; idempotency_key:string; request_hash:string; result:Json|null; status:string }>;
  customers: Table<{ address:string|null; city:string|null; created_at:string; customer_code:string; id:string; name:string; normalized_phone:string|null; phone:string|null; updated_at:string }>;
  delivery_outcomes: Table<{ id:string; note:string|null; occurred_at:string; outcome:string; parcel_id:string; performed_by:string }>;
  financial_adjustments: Table<{ adjustment_type:string; cod_receipt_id:string|null; delta_amount:number; id:string; order_id:string; parcel_id:string|null; performed_at:string; performed_by:string; reason:string }>;
  import_batches: Table<{ completed_at:string|null; id:string; initiated_by:string; reconciliation_summary:Json|null; source_file:string; source_system:string; started_at:string|null; status:string }>;
  import_rows: Table<{ batch_id:string; error:string|null; id:string; normalized_data:Json|null; raw_data:Json; source_record_id:string|null; source_row_number:number; status:string }>;
  invoice_records: Table<{ generated_at:string; generated_by:string; id:string; invoice_number:string; order_id:string; print_count:number; template_version:string }>;
  order_events: Table<{ event_time:string; event_type:string; id:string; metadata:Json; notes:string|null; order_id:string; parcel_id:string|null; performed_by:string }>;
  order_items: Table<{ created_at:string; description:string; id:string; line_no:number; order_id:string; quantity:number; updated_at:string }>;
  orders: Table<{ created_at:string; created_by:string; currency_code:string; customer_id:string; fulfillment_summary:string|null; id:string; lifecycle_state:string; notes:string|null; order_date:string; order_number:string; original_amount:number; updated_at:string }>;
  parcel_items: Table<{ allocation_state:string; created_at:string; id:string; order_item_id:string; parcel_id:string; quantity:number; updated_at:string }>;
  parcels: Table<{ barcode:string; created_at:string; dispatch_at:string|null; id:string; order_id:string; parcel_number:string; rto_at:string|null; shipper_id:string|null; state:string; tracking_id:string|null; updated_at:string }>;
  profiles: Table<{ active:boolean; created_at:string; email:string; id:string; name:string; role:string; updated_at:string }>;
  shippers: Table<{ active:boolean; created_at:string; id:string; name:string; updated_at:string }>;
};
export type Database = { __InternalSupabase:{PostgrestVersion:"14.5"}; public:{ Tables:PublicTables; Views:Record<string,never>; Functions:Record<string,{Args:Record<string,unknown>;Returns:unknown}>; Enums:Record<string,never>; CompositeTypes:Record<string,never> } };
export type Tables<T extends keyof PublicTables> = PublicTables[T]["Row"];
export type TablesInsert<T extends keyof PublicTables> = PublicTables[T]["Insert"];
export type TablesUpdate<T extends keyof PublicTables> = PublicTables[T]["Update"];
export type Enums<T extends keyof Database["public"]["Enums"]> = Database["public"]["Enums"][T];
