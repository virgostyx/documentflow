# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_07_115532) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "change_data", default: {}
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "company"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "entity_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["entity_id", "email"], name: "index_contacts_on_entity_id_and_email", unique: true
    t.index ["entity_id"], name: "index_contacts_on_entity_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "addressee_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.date "document_date", null: false
    t.bigint "entity_id", null: false
    t.boolean "is_frozen", default: false, null: false
    t.string "reference_number", null: false
    t.bigint "sender_id", null: false
    t.string "status", default: "draft", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["addressee_id"], name: "index_documents_on_addressee_id"
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["entity_id", "reference_number"], name: "index_documents_on_entity_id_and_reference_number", unique: true
    t.index ["entity_id"], name: "index_documents_on_entity_id"
    t.index ["sender_id"], name: "index_documents_on_sender_id"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "entities", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_entities_on_code", unique: true
    t.index ["name"], name: "index_entities_on_name", unique: true
    t.index ["status"], name: "index_entities_on_status"
  end

  create_table "entity_users", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "invitation_token"
    t.datetime "invited_at"
    t.bigint "invited_by_id"
    t.string "invited_email", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["entity_id", "user_id"], name: "index_entity_users_on_entity_id_and_user_id", unique: true
    t.index ["entity_id"], name: "index_entity_users_on_entity_id"
    t.index ["invitation_token"], name: "index_entity_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_entity_users_on_invited_by_id"
    t.index ["role"], name: "index_entity_users_on_role"
    t.index ["status"], name: "index_entity_users_on_status"
    t.index ["user_id"], name: "index_entity_users_on_user_id"
  end

  create_table "shared_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_shared_links_on_document_id"
    t.index ["token"], name: "index_shared_links_on_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.boolean "super_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workflow_steps", force: :cascade do |t|
    t.bigint "actor_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.boolean "is_parallel", default: false, null: false
    t.integer "order", null: false
    t.integer "parallel_group"
    t.string "role", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_workflow_steps_on_actor_id"
    t.index ["document_id", "order"], name: "index_workflow_steps_on_document_id_and_order", unique: true
    t.index ["document_id"], name: "index_workflow_steps_on_document_id"
    t.index ["role"], name: "index_workflow_steps_on_role"
    t.index ["status"], name: "index_workflow_steps_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "contacts", "entities"
  add_foreign_key "documents", "contacts", column: "addressee_id"
  add_foreign_key "documents", "contacts", column: "sender_id"
  add_foreign_key "documents", "entities"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "entity_users", "entities"
  add_foreign_key "entity_users", "users"
  add_foreign_key "entity_users", "users", column: "invited_by_id"
  add_foreign_key "shared_links", "documents"
  add_foreign_key "workflow_steps", "documents"
  add_foreign_key "workflow_steps", "users", column: "actor_id"
end
