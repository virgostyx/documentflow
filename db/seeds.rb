# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

PASSWORD = "password123"
SAMPLE_FILE = Rails.root.join("spec/fixtures/files/sample.pdf")

def find_or_create_user!(email:, first_name:, last_name:, super_admin: false)
  User.find_or_create_by!(email: email) do |user|
    user.first_name = first_name
    user.last_name = last_name
    user.password = PASSWORD
    user.password_confirmation = PASSWORD
    user.super_admin = super_admin
  end
end

def add_member!(entity:, user:, role:, inviter:)
  EntityUser.find_or_create_by!(entity: entity, user: user) do |eu|
    eu.invited_email = user.email
    eu.role = role
    eu.status = "active"
    eu.invited_by = inviter
    eu.accepted_at = Time.current
  end
end

def add_pending_invitation!(entity:, email:, role:, inviter:)
  EntityUser.find_or_create_by!(entity: entity, invited_email: email) do |eu|
    eu.role = role
    eu.status = "pending"
    eu.invited_by = inviter
  end
end

def add_department!(entity:, name:, is_default: false)
  entity.departments.find_or_create_by!(name: name) { |d| d.is_default = is_default }
end

def assign_department!(entity_user:, department:, primary: false)
  EntityUserDepartment.find_or_create_by!(entity_user: entity_user, department: department) do |eud|
    eud.primary = primary
  end
end

def add_contact!(entity:, first_name:, last_name:, email:, company:, phone:)
  entity.contacts.find_or_create_by!(email: email) do |contact|
    contact.first_name = first_name
    contact.last_name = last_name
    contact.company = company
    contact.phone = phone
  end
end

def add_template_step!(template, order:, role:, actor: nil, is_parallel: false, parallel_group: nil)
  template.circuit_template_steps.find_or_create_by!(order: order) do |step|
    step.role = role
    step.actor = actor
    step.is_parallel = is_parallel
    step.parallel_group = parallel_group
  end
end

def add_document!(entity:, subject:, department:, created_by:, sender:, addressee:, status:, is_frozen: false, document_date: Date.current, expects_response: false)
  entity.documents.find_or_create_by!(subject: subject) do |doc|
    doc.department = department
    doc.created_by = created_by
    doc.sender = sender
    doc.addressee = addressee
    doc.document_date = document_date
    doc.status = status
    doc.is_frozen = is_frozen
    doc.expects_response = expects_response
  end
end

def add_step!(document, order:, role:, status:, actor: nil, is_parallel: false, parallel_group: nil, comment: nil)
  document.workflow_steps.find_or_create_by!(order: order) do |step|
    step.role = role
    step.status = status
    step.actor = actor
    step.is_parallel = is_parallel
    step.parallel_group = parallel_group
    step.comment = comment
  end
end

def attach_main_file!(document)
  return if document.main_file.attached?

  document.main_file.attach(
    io: File.open(SAMPLE_FILE), filename: "main-document.pdf", content_type: "application/pdf"
  )
end

def attach_annexes!(document, filenames)
  return if document.annexes.attached?

  filenames.each do |filename|
    document.annexes.attach(
      io: File.open(SAMPLE_FILE), filename: filename, content_type: "application/pdf"
    )
  end
end

def add_cc!(document, party)
  document.cc_recipients.find_or_create_by!(party: party)
end

def add_shared_link!(document, expires_at: nil)
  return if document.shared_links.exists?

  document.shared_links.create!(expires_at: expires_at)
end

puts "== Seeding users =="
olivia = find_or_create_user!(email: "olivia.bennett@documentflow.example", first_name: "Olivia", last_name: "Bennett", super_admin: true)
marcus = find_or_create_user!(email: "marcus.chen@acme-mfg.example", first_name: "Marcus", last_name: "Chen")
sophia = find_or_create_user!(email: "sophia.rodriguez@acme-mfg.example", first_name: "Sophia", last_name: "Rodriguez")
james  = find_or_create_user!(email: "james.whitfield@acme-mfg.example", first_name: "James", last_name: "Whitfield")
priya  = find_or_create_user!(email: "priya.patel@northbridge.example", first_name: "Priya", last_name: "Patel")
daniel = find_or_create_user!(email: "daniel.okafor@northbridge.example", first_name: "Daniel", last_name: "Okafor")
emma   = find_or_create_user!(email: "emma.thompson@harborview.example", first_name: "Emma", last_name: "Thompson")
liam   = find_or_create_user!(email: "liam.carter@harborview.example", first_name: "Liam", last_name: "Carter")
fatima = find_or_create_user!(email: "fatima.alsayed@acme-mfg.example", first_name: "Fatima", last_name: "Al-Sayed")

puts "== Seeding entities =="
acme        = Entity.find_or_create_by!(name: "Acme Manufacturing Ltd") { |e| e.status = "active" }
northbridge = Entity.find_or_create_by!(name: "Northbridge Consulting Group") { |e| e.status = "active" }
harborview  = Entity.find_or_create_by!(name: "Harborview Logistics Inc") { |e| e.status = "active" }

puts "== Seeding entity memberships =="
add_member!(entity: acme, user: marcus, role: "owner", inviter: marcus)
add_member!(entity: acme, user: sophia, role: "admin", inviter: marcus)
add_member!(entity: acme, user: james, role: "member", inviter: marcus)
add_member!(entity: acme, user: olivia, role: "admin", inviter: marcus)
add_pending_invitation!(entity: acme, email: "grace.kim@acme-mfg.example", role: "member", inviter: marcus)

add_member!(entity: northbridge, user: priya, role: "owner", inviter: priya)
add_member!(entity: northbridge, user: daniel, role: "admin", inviter: priya)
add_member!(entity: northbridge, user: marcus, role: "guest", inviter: priya)
add_member!(entity: northbridge, user: olivia, role: "admin", inviter: priya)

add_member!(entity: harborview, user: emma, role: "owner", inviter: emma)
add_member!(entity: harborview, user: liam, role: "member", inviter: emma)
add_member!(entity: harborview, user: priya, role: "guest", inviter: emma)
add_member!(entity: harborview, user: olivia, role: "admin", inviter: emma)

puts "== Seeding departments =="
acme_sales      = add_department!(entity: acme, name: "Sales")
acme_finance    = add_department!(entity: acme, name: "Finance & Administration")
acme_operations = add_department!(entity: acme, name: "Operations")

northbridge_advisory = add_department!(entity: northbridge, name: "Advisory Services")
northbridge_finance  = add_department!(entity: northbridge, name: "Finance & Administration")

harborview_logistics = add_department!(entity: harborview, name: "Logistics Operations")
harborview_finance   = add_department!(entity: harborview, name: "Finance & Administration")

puts "== Assigning members to departments =="
# james belongs to a single department: he only sees Operations documents.
james_acme_membership = EntityUser.find_by(entity: acme, user: james)
assign_department!(entity_user: james_acme_membership, department: acme_operations, primary: true)

# fatima is a regular member who oversees two departments at once (the
# "Finance & Administration Director" scenario): she sees documents from both,
# but not from Operations.
fatima_acme_membership = add_member!(entity: acme, user: fatima, role: "member", inviter: marcus)
assign_department!(entity_user: fatima_acme_membership, department: acme_finance, primary: true)
assign_department!(entity_user: fatima_acme_membership, department: acme_sales)

# marcus is only a guest in Northbridge: he is scoped to Advisory Services there.
marcus_northbridge_membership = EntityUser.find_by(entity: northbridge, user: marcus)
assign_department!(entity_user: marcus_northbridge_membership, department: northbridge_advisory, primary: true)

# liam belongs to a single department in Harborview.
liam_harborview_membership = EntityUser.find_by(entity: harborview, user: liam)
assign_department!(entity_user: liam_harborview_membership, department: harborview_logistics, primary: true)

# priya is only a guest in Harborview: she is scoped to Finance & Administration there.
priya_harborview_membership = EntityUser.find_by(entity: harborview, user: priya)
assign_department!(entity_user: priya_harborview_membership, department: harborview_finance, primary: true)

puts "== Seeding contacts =="
robert_hayes   = add_contact!(entity: acme, first_name: "Robert", last_name: "Hayes", email: "robert.hayes@hayesco.example", company: "Hayes & Co Distribution", phone: "+1 415 555 0142")
linda_martinez = add_contact!(entity: acme, first_name: "Linda", last_name: "Martinez", email: "linda.martinez@martinezsupply.example", company: "Martinez Supply Chain", phone: "+1 415 555 0198")

thomas_reed   = add_contact!(entity: northbridge, first_name: "Thomas", last_name: "Reed", email: "thomas.reed@reedcapital.example", company: "Reed Capital Partners", phone: "+1 212 555 0110")
nadia_hussain = add_contact!(entity: northbridge, first_name: "Nadia", last_name: "Hussain", email: "nadia.hussain@hussainassociates.example", company: "Hussain & Associates", phone: "+1 212 555 0173")

anna_kowalski = add_contact!(entity: harborview, first_name: "Anna", last_name: "Kowalski", email: "anna.kowalski@kowalskifreight.example", company: "Kowalski Freight Services", phone: "+1 312 555 0125")
carlos_mendes = add_contact!(entity: harborview, first_name: "Carlos", last_name: "Mendes", email: "carlos.mendes@mendesshipping.example", company: "Mendes Shipping Co", phone: "+1 312 555 0188")

puts "== Seeding circuit templates =="
acme_standard = CircuitTemplate.find_or_create_by!(entity: acme, name: "Standard Approval")
add_template_step!(acme_standard, order: 1, role: "RED", actor: james)
add_template_step!(acme_standard, order: 2, role: "VISA", actor: sophia)
add_template_step!(acme_standard, order: 3, role: "SIGN", actor: marcus)
add_template_step!(acme_standard, order: 4, role: "EXP", actor: james)

acme_dual = CircuitTemplate.find_or_create_by!(entity: acme, name: "Dual Review")
add_template_step!(acme_dual, order: 1, role: "RED", actor: james)
add_template_step!(acme_dual, order: 2, role: "VISA", actor: sophia, is_parallel: true, parallel_group: 1)
add_template_step!(acme_dual, order: 3, role: "VISA", actor: marcus, is_parallel: true, parallel_group: 1)
add_template_step!(acme_dual, order: 4, role: "SIGN", actor: marcus)
add_template_step!(acme_dual, order: 5, role: "EXP", actor: james)

northbridge_standard = CircuitTemplate.find_or_create_by!(entity: northbridge, name: "Standard Approval")
add_template_step!(northbridge_standard, order: 1, role: "RED", actor: daniel)
add_template_step!(northbridge_standard, order: 2, role: "VISA", actor: priya)
add_template_step!(northbridge_standard, order: 3, role: "SIGN", actor: priya)
add_template_step!(northbridge_standard, order: 4, role: "EXP", actor: daniel)

harborview_standard = CircuitTemplate.find_or_create_by!(entity: harborview, name: "Standard Approval")
add_template_step!(harborview_standard, order: 1, role: "RED", actor: liam)
add_template_step!(harborview_standard, order: 2, role: "VISA", actor: emma)
add_template_step!(harborview_standard, order: 3, role: "SIGN", actor: emma)
add_template_step!(harborview_standard, order: 4, role: "EXP", actor: liam)

puts "== Seeding documents for Acme Manufacturing Ltd =="

add_document!(
  entity: acme, subject: "Service Agreement Renewal - Hayes & Co Distribution", department: acme_sales,
  created_by: sophia, sender: sophia, addressee: robert_hayes, status: "draft"
)

doc = add_document!(
  entity: acme, subject: "Purchase Order #2026-014 - Martinez Supply Chain", department: acme_operations,
  created_by: james, sender: james, addressee: linda_martinez, status: "in_progress"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: james)
add_step!(doc, order: 2, role: "VISA", status: "pending", actor: sophia)
add_step!(doc, order: 3, role: "SIGN", status: "pending", actor: marcus)
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: james)
add_cc!(doc, sophia)

doc = add_document!(
  entity: acme, subject: "Non-Disclosure Agreement - Hayes & Co Distribution", department: acme_finance,
  created_by: sophia, sender: sophia, addressee: robert_hayes, status: "signed"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: james)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: sophia, comment: "Reviewed and approved without changes.")
add_step!(doc, order: 3, role: "SIGN", status: "approved", actor: marcus)
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: james)
add_cc!(doc, linda_martinez)

doc = add_document!(
  entity: acme, subject: "Annual Compliance Report 2025", department: acme_finance,
  created_by: marcus, sender: marcus, addressee: james, status: "finalized", is_frozen: true
)
attach_main_file!(doc)
attach_annexes!(doc, [ "appendix-a-risk-assessment.pdf", "appendix-b-certifications.pdf" ])
add_step!(doc, order: 1, role: "RED", status: "approved", actor: james)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: sophia, is_parallel: true, parallel_group: 1)
add_step!(doc, order: 3, role: "VISA", status: "approved", actor: marcus, is_parallel: true, parallel_group: 1)
add_step!(doc, order: 4, role: "SIGN", status: "approved", actor: marcus)
add_step!(doc, order: 5, role: "EXP", status: "approved", actor: james)
add_shared_link!(doc)

add_document!(
  entity: acme, subject: "Equipment Lease Proposal (Cancelled)", department: acme_sales,
  created_by: sophia, sender: sophia, addressee: linda_martinez, status: "cancelled"
)

# ToDo for james: he is the addressee and a response is expected from him.
add_document!(
  entity: acme, subject: "Quote Request - Need Confirmation from Operations", department: acme_operations,
  created_by: marcus, sender: marcus, addressee: james, status: "in_progress", expects_response: true
)

# Waiting for james (he created it and is awaiting Martinez Supply Chain's reply);
# Info for sophia, who is cc'd and therefore not on the hook for a response.
doc = add_document!(
  entity: acme, subject: "Updated Pricing Sheet - Martinez Supply Chain", department: acme_operations,
  created_by: james, sender: james, addressee: linda_martinez, status: "in_progress", expects_response: true
)
add_cc!(doc, sophia)

puts "== Seeding documents for Northbridge Consulting Group =="

add_document!(
  entity: northbridge, subject: "Consulting Proposal - Reed Capital Partners", department: northbridge_advisory,
  created_by: daniel, sender: daniel, addressee: thomas_reed, status: "draft"
)

doc = add_document!(
  entity: northbridge, subject: "Engagement Letter - Hussain & Associates", department: northbridge_advisory,
  created_by: daniel, sender: daniel, addressee: nadia_hussain, status: "in_progress"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: daniel)
add_step!(doc, order: 2, role: "VISA", status: "pending", actor: priya)
add_step!(doc, order: 3, role: "SIGN", status: "pending", actor: priya)
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: daniel)
add_cc!(doc, marcus)

doc = add_document!(
  entity: northbridge, subject: "Master Services Agreement - Reed Capital Partners", department: northbridge_advisory,
  created_by: priya, sender: priya, addressee: thomas_reed, status: "signed"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: daniel)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: priya)
add_step!(doc, order: 3, role: "SIGN", status: "approved", actor: priya, comment: "Signed after final pricing review.")
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: daniel)

doc = add_document!(
  entity: northbridge, subject: "Quarterly Advisory Report - Q4 2025", department: northbridge_finance,
  created_by: priya, sender: priya, addressee: daniel, status: "finalized", is_frozen: true
)
attach_main_file!(doc)
attach_annexes!(doc, [ "appendix-financial-summary.pdf" ])
add_step!(doc, order: 1, role: "RED", status: "approved", actor: daniel)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: priya)
add_step!(doc, order: 3, role: "SIGN", status: "approved", actor: priya)
add_step!(doc, order: 4, role: "EXP", status: "approved", actor: daniel)
add_shared_link!(doc)

add_document!(
  entity: northbridge, subject: "Partnership Term Sheet (Withdrawn)", department: northbridge_advisory,
  created_by: daniel, sender: daniel, addressee: nadia_hussain, status: "cancelled"
)

# ToDo for daniel: he is the addressee and a response is expected from him.
add_document!(
  entity: northbridge, subject: "Budget Approval Needed - Q1 2026", department: northbridge_finance,
  created_by: priya, sender: priya, addressee: daniel, status: "in_progress", expects_response: true
)

# Waiting for priya (she created it and is awaiting Reed Capital's reply);
# Info for daniel, who is cc'd and therefore not on the hook for a response.
doc = add_document!(
  entity: northbridge, subject: "Updated Engagement Terms - Reed Capital Partners", department: northbridge_advisory,
  created_by: priya, sender: priya, addressee: thomas_reed, status: "in_progress", expects_response: true
)
add_cc!(doc, daniel)

puts "== Seeding documents for Harborview Logistics Inc =="

add_document!(
  entity: harborview, subject: "Freight Forwarding Agreement - Kowalski Freight Services", department: harborview_logistics,
  created_by: liam, sender: liam, addressee: anna_kowalski, status: "draft"
)

doc = add_document!(
  entity: harborview, subject: "Customs Brokerage Contract - Mendes Shipping Co", department: harborview_logistics,
  created_by: liam, sender: liam, addressee: carlos_mendes, status: "in_progress"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: liam)
add_step!(doc, order: 2, role: "VISA", status: "pending", actor: emma)
add_step!(doc, order: 3, role: "SIGN", status: "pending", actor: emma)
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: liam)
add_cc!(doc, priya)

doc = add_document!(
  entity: harborview, subject: "Warehouse Lease Renewal - Kowalski Freight Services", department: harborview_logistics,
  created_by: emma, sender: emma, addressee: anna_kowalski, status: "signed"
)
attach_main_file!(doc)
add_step!(doc, order: 1, role: "RED", status: "approved", actor: liam)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: emma)
add_step!(doc, order: 3, role: "SIGN", status: "approved", actor: emma)
add_step!(doc, order: 4, role: "EXP", status: "pending", actor: liam)

doc = add_document!(
  entity: harborview, subject: "Annual Safety Compliance Certificate 2025", department: harborview_finance,
  created_by: emma, sender: emma, addressee: liam, status: "finalized", is_frozen: true
)
attach_main_file!(doc)
attach_annexes!(doc, [ "appendix-inspection-report.pdf" ])
add_step!(doc, order: 1, role: "RED", status: "approved", actor: liam)
add_step!(doc, order: 2, role: "VISA", status: "approved", actor: emma)
add_step!(doc, order: 3, role: "SIGN", status: "approved", actor: emma)
add_step!(doc, order: 4, role: "EXP", status: "approved", actor: liam)
add_shared_link!(doc, expires_at: 1.day.ago)

add_document!(
  entity: harborview, subject: "Fleet Maintenance Contract (Cancelled Draft)", department: harborview_logistics,
  created_by: liam, sender: liam, addressee: carlos_mendes, status: "cancelled"
)

# ToDo for liam: he is the addressee and a response is expected from him.
add_document!(
  entity: harborview, subject: "Insurance Renewal Confirmation Needed", department: harborview_logistics,
  created_by: emma, sender: emma, addressee: liam, status: "in_progress", expects_response: true
)

# Waiting for emma (she created it and is awaiting Mendes Shipping's reply);
# Info for liam, who is cc'd and therefore not on the hook for a response.
doc = add_document!(
  entity: harborview, subject: "Rate Adjustment Proposal - Mendes Shipping Co", department: harborview_logistics,
  created_by: emma, sender: emma, addressee: carlos_mendes, status: "in_progress", expects_response: true
)
add_cc!(doc, liam)

puts "\nSeed data created successfully."
puts "Entities: #{Entity.count}, Departments: #{Department.count}, Users: #{User.count}, Contacts: #{Contact.count}, Documents: #{Document.count}"
puts "All seeded users share the password: #{PASSWORD}"
puts "Super admin login: olivia.bennett@documentflow.example"
