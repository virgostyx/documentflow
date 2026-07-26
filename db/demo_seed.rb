# frozen_string_literal: true

#
# Sets up a dedicated, self-contained demo Entity for live sales/prospect demos.
# Does NOT touch db/seeds.rb data. Idempotent (safe to run more than once, in any environment).
#
# Usage:
#   bin/rails runner db/demo_seed.rb
#
# Deliberately does NOT create the demo document itself — that is created live
# during the demo to show the registration step. Full walkthrough script:
# docs/dev/demo/script.md

DEMO_PASSWORD = "MeridianDemo2026!"

def find_or_create_demo_user!(email:, first_name:, last_name:)
  User.find_or_create_by!(email: email) do |user|
    user.first_name = first_name
    user.last_name = last_name
    user.password = DEMO_PASSWORD
    user.password_confirmation = DEMO_PASSWORD
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

def assign_department!(entity_user:, department:, primary: false)
  EntityUserDepartment.find_or_create_by!(entity_user: entity_user, department: department) do |eud|
    eud.primary = primary
  end
end

puts "== Seeding demo entity =="
meridian = Entity.find_or_create_by!(name: "Meridian Advisory Group") do |e|
  e.status = "active"
  e.prefix = "MERIDIAN"
end

admin_dept = meridian.departments.find_or_create_by!(name: "General Administration") do |d|
  d.prefix = "ADMIN"
  d.is_default = true
end

puts "== Seeding demo users =="
sarah = find_or_create_demo_user!(email: "virgostyx+sarah@gmail.com", first_name: "Sarah", last_name: "Kone")
david = find_or_create_demo_user!(email: "virgostyx+david@gmail.com", first_name: "David", last_name: "Mensah")
amara = find_or_create_demo_user!(email: "virgostyx+amara@gmail.com", first_name: "Amara", last_name: "Diallo")

amara_membership = add_member!(entity: meridian, user: amara, role: "owner", inviter: amara)
david_membership = add_member!(entity: meridian, user: david, role: "admin", inviter: amara)
sarah_membership = add_member!(entity: meridian, user: sarah, role: "member", inviter: amara)

# Members (unlike owners/admins) can only create documents in a department they belong to
# (see DocumentPolicy#create?) — assign all three so nobody hits a hidden "New document" button.
assign_department!(entity_user: amara_membership, department: admin_dept, primary: true)
assign_department!(entity_user: david_membership, department: admin_dept, primary: true)
assign_department!(entity_user: sarah_membership, department: admin_dept, primary: true)

puts "== Seeding demo contact (addressee) =="
youssef = meridian.contacts.find_or_create_by!(email: "virgostyx+youssef@gmail.com") do |contact|
  contact.first_name = "Youssef"
  contact.last_name = "Traoré"
  contact.company = "Traoré & Partners"
  contact.phone = "+225 27 22 40 11 05"
end

puts "== Seeding circuit template =="
template = CircuitTemplate.find_or_create_by!(entity: meridian, name: "Standard Notice")
template.circuit_template_steps.find_or_create_by!(order: 1) { |s| s.role = "RED";  s.actor = sarah }
template.circuit_template_steps.find_or_create_by!(order: 2) { |s| s.role = "VISA"; s.actor = david }
template.circuit_template_steps.find_or_create_by!(order: 3) { |s| s.role = "SIGN"; s.actor = amara }
template.circuit_template_steps.find_or_create_by!(order: 4) { |s| s.role = "EXP";  s.actor = sarah }

puts "\nDemo entity ready: #{meridian.name} (#{meridian.prefix})"
puts "Department: #{admin_dept.name} (#{admin_dept.prefix})"
puts "Addressee contact: #{youssef.first_name} #{youssef.last_name} - #{youssef.company}"
puts "Circuit template: #{template.name} (RED->VISA->SIGN->EXP)"
puts "\nDemo accounts (all share the same password):"
puts "  Sarah Kone  (Executive Assistant / RED+EXP) - #{sarah.email}"
puts "  David Mensah (Department Director / VISA)   - #{david.email}"
puts "  Amara Diallo (General Manager / SIGN)        - #{amara.email}"
puts "  Password: #{DEMO_PASSWORD}"
puts "\nAttach docs/dev/demo/office_relocation_notice.pdf as the main file when creating the demo document."
