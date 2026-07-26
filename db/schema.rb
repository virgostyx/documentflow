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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_094124) do
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

  create_table "annexes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_annexes_on_document_id"
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

  create_table "cc_recipients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "party_id", null: false
    t.string "party_type", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "party_type", "party_id"], name: "index_cc_recipients_unique", unique: true
    t.index ["document_id"], name: "index_cc_recipients_on_document_id"
    t.index ["party_type", "party_id"], name: "index_cc_recipients_on_party_type_and_party_id"
  end

  create_table "circuit_template_steps", force: :cascade do |t|
    t.bigint "actor_id"
    t.bigint "circuit_template_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_parallel", default: false, null: false
    t.integer "order", null: false
    t.integer "parallel_group"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["circuit_template_id", "order"], name: "index_circuit_template_steps_on_circuit_template_id_and_order", unique: true
    t.index ["circuit_template_id"], name: "index_circuit_template_steps_on_circuit_template_id"
  end

  create_table "circuit_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "name"], name: "index_circuit_templates_on_entity_id_and_name", unique: true
    t.index ["entity_id"], name: "index_circuit_templates_on_entity_id"
  end

  create_table "classification_nodes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "depth", null: false
    t.bigint "entity_id", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["entity_id", "code"], name: "index_classification_nodes_on_entity_and_code", unique: true
    t.index ["entity_id", "parent_id", "name"], name: "index_classification_nodes_on_entity_parent_name", unique: true
    t.index ["entity_id"], name: "index_classification_nodes_on_entity_id"
    t.index ["parent_id"], name: "index_classification_nodes_on_parent_id"
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

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.boolean "is_default", default: false, null: false
    t.string "name", null: false
    t.string "prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "name"], name: "index_departments_on_entity_id_and_name", unique: true
    t.index ["entity_id", "prefix"], name: "index_departments_on_entity_id_and_prefix", unique: true
    t.index ["entity_id"], name: "index_departments_on_entity_id"
  end

  create_table "document_file_versions", force: :cascade do |t|
    t.bigint "annex_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "version_number", null: false
    t.index ["annex_id"], name: "index_document_file_versions_on_annex_id"
    t.index ["document_id", "annex_id", "version_number"], name: "index_document_file_versions_on_document_annex_version", unique: true
    t.index ["document_id"], name: "index_document_file_versions_on_document_id"
    t.index ["user_id"], name: "index_document_file_versions_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "addressee_id", null: false
    t.string "addressee_type", null: false
    t.datetime "checked_out_at"
    t.bigint "checked_out_by_id"
    t.bigint "classification_node_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "department_id", null: false
    t.string "direction", default: "outgoing", null: false
    t.date "document_date", null: false
    t.bigint "entity_id", null: false
    t.boolean "expects_response", default: false, null: false
    t.bigint "in_reply_to_id"
    t.boolean "is_frozen", default: false, null: false
    t.bigint "lead_user_id"
    t.string "reference_number", null: false
    t.date "response_deadline"
    t.datetime "routed_at"
    t.text "routing_message"
    t.bigint "sender_id", null: false
    t.string "sender_type", null: false
    t.datetime "shared_link_renewed_at"
    t.string "status", default: "draft", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["addressee_type", "addressee_id"], name: "index_documents_on_addressee_type_and_addressee_id"
    t.index ["checked_out_by_id"], name: "index_documents_on_checked_out_by_id"
    t.index ["classification_node_id"], name: "index_documents_on_classification_node_id"
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["department_id"], name: "index_documents_on_department_id"
    t.index ["entity_id", "reference_number"], name: "index_documents_on_entity_id_and_reference_number", unique: true
    t.index ["entity_id"], name: "index_documents_on_entity_id"
    t.index ["in_reply_to_id"], name: "index_documents_on_in_reply_to_id"
    t.index ["lead_user_id"], name: "index_documents_on_lead_user_id"
    t.index ["sender_type", "sender_id"], name: "index_documents_on_sender_type_and_sender_id"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "entities", force: :cascade do |t|
    t.string "acronym"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "prefix", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_entities_on_code", unique: true
    t.index ["name"], name: "index_entities_on_name", unique: true
    t.index ["prefix"], name: "index_entities_on_prefix", unique: true
    t.index ["status"], name: "index_entities_on_status"
  end

  create_table "entity_user_departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.bigint "entity_user_id", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_entity_user_departments_on_department_id"
    t.index ["entity_user_id", "department_id"], name: "idx_on_entity_user_id_department_id_be10080a56", unique: true
    t.index ["entity_user_id"], name: "index_entity_user_departments_on_entity_user_id"
    t.index ["entity_user_id"], name: "index_one_primary_department_per_entity_user", unique: true, where: "\"primary\""
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
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
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
  add_foreign_key "annexes", "documents"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "cc_recipients", "documents"
  add_foreign_key "circuit_template_steps", "circuit_templates"
  add_foreign_key "circuit_template_steps", "users", column: "actor_id"
  add_foreign_key "circuit_templates", "entities"
  add_foreign_key "classification_nodes", "classification_nodes", column: "parent_id"
  add_foreign_key "classification_nodes", "entities"
  add_foreign_key "contacts", "entities"
  add_foreign_key "departments", "entities"
  add_foreign_key "document_file_versions", "annexes"
  add_foreign_key "document_file_versions", "documents"
  add_foreign_key "document_file_versions", "users"
  add_foreign_key "documents", "classification_nodes"
  add_foreign_key "documents", "departments"
  add_foreign_key "documents", "documents", column: "in_reply_to_id"
  add_foreign_key "documents", "entities"
  add_foreign_key "documents", "users", column: "checked_out_by_id"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "documents", "users", column: "lead_user_id"
  add_foreign_key "entity_user_departments", "departments"
  add_foreign_key "entity_user_departments", "entity_users"
  add_foreign_key "entity_users", "entities"
  add_foreign_key "entity_users", "users"
  add_foreign_key "entity_users", "users", column: "invited_by_id"
  add_foreign_key "shared_links", "documents"
  add_foreign_key "workflow_steps", "documents"
  add_foreign_key "workflow_steps", "users", column: "actor_id"
end
