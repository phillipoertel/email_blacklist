require 'ostruct'
require 'yaml'
require 'shellwords'

def load_config
  yaml = YAML.load_file('config.yml')
  OpenStruct.new(yaml)
end

def extract_emails(folder_path)
  files = Dir.glob(File.join(Shellwords.escape(folder_path), '**/*.emlx'))
  results = files.map do |file| 
    content = File.read(file).force_encoding("ISO-8859-1")
    content.scan(/^From: .+<(.+)>$/)
  end
  results
    .flatten
    .grep(/^[a-z0-9_\-\.@]+$/i) { |email| email.downcase.strip }
    .uniq
    .sort
end

def extract_domains(emails)
  emails.map { |email| email.split('@').last }.uniq.sort
end

def write(file, emails)
  File.open(file, 'w') { |f| f.write(emails.join("\n").strip) }
end

def emails_for_folders(mail_root, folder_names)
  folder_names.map do |folder_name|
    folder_path = File.join(mail_root, "#{folder_name}.mbox")
    extract_emails(folder_path)
  end.flatten
end

def build_list(name, mail_root, folders, exclude_patterns = [])
  emails     = emails_for_folders(mail_root, folders)
  old_emails = File.read("old_#{name}.txt").split("\n").map { |e| e.downcase }
  emails     = emails + old_emails
  emails.reject! do |email| 
    exclude_patterns.any? { |exclude_pattern| email =~ /#{exclude_pattern}/ }
  end
  domains    = extract_domains(emails).uniq
  write("#{name}.txt", domains)
  puts "Wrote list '#{name}' with #{domains.size} entries."
  domains
end

config = load_config

START = Time.now

blacklist_domains = build_list(:blacklist, config.mail_root, config.blacklist_folders, config.never_blacklist)
whitelist_domains = build_list(:whitelist, config.mail_root, config.whitelist_folders)

# check if domains are on both whitelist and blacklist
intersection = blacklist_domains & whitelist_domains
unless intersection.empty?
  puts "Warning: the following domains are both on whitelist and blacklist:"
  puts '- ' + intersection.sort.join("\n- ")
end

puts "\nProcessing took #{Time.now - START}s."