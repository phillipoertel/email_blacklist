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

config = load_config

START = Time.now
#
# blacklist
#
folders = config.blacklist_folders
emails = emails_for_folders(config.mail_root, folders)

old_emails = File.read('old_blacklist.txt').split("\n").map { |e| e.downcase }

emails = emails + old_emails
emails.reject! { |email| config.never_blacklist.any? { |never_blacklist_pattern| email =~ /#{never_blacklist_pattern}/ } }

blacklist_domains = extract_domains(emails).uniq
write('blacklist.txt', blacklist_domains)
puts "Wrote blacklist with #{`wc -l blacklist.txt`.split.first.strip} entries."

#
# whitelist
#
folders = config.whitelist_folders
emails = emails_for_folders(config.mail_root, folders)

old_emails = File.read('old_whitelist.txt').split("\n").map { |e| e.downcase }

emails = (emails + old_emails)

whitelist_domains = extract_domains(emails).uniq
write('whitelist.txt', whitelist_domains)
puts "Wrote whitelist with #{`wc -l whitelist.txt`.split.first.strip} entries."

# check if domains are on both whitelist and blacklist
intersection = blacklist_domains & whitelist_domains
unless intersection.empty?
  puts "Warning: the following domains are both on whitelist and blacklist:"
  puts '- ' + intersection.sort.join("\n- ")
end

puts "\nProcessing took #{Time.now - START}s."