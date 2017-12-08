require 'date'

FILE_NAME = '1234'

VISA_END = '1234'

raw_file = File.read FILE_NAME

sms_regex = /<sms protocol="(?<protocol>[^"]+)" address="(?<address>[^"]+)" date="(?<date>[^"]+)" type="(?<type>[^"]+)" subject="(?<subject>[^"]+)" body=(?<body>('[^']*')|("[^"]*")) toa="(?<toa>[^"]+)" sc_toa="(?<sc_toa>[^"]+)" service_center="(?<service_center>[^"]+)" read="(?<read>[^"]+)" status="(?<status>[^"]+)" locked="(?<locked>[^"]+)" date_sent="(?<date_sent>[^"]+)" readable_date="(?<readable_date>[^"]+)" contact_name="(?<contact_name>[^"]+)" \/>/

sms_entry_count = raw_file.scan(/<sms /).length

smses = raw_file.each_line.map { |a| sms_regex.match(a) }.compact.map { |a| a.named_captures }

puts 'DISCREPANCY DETECTED' unless sms_entry_count == smses.length

smses.each do |sms|
    sms['date'] = DateTime.strptime sms['date'], '%Q'
    sms['date_sent'] = DateTime.strptime sms['date_sent'], '%Q'
    sms['body'] = sms['body'][1...-1]
    sms['type'] = case sms['type']
        when '1'
            'received'
        when '2'
            'sent'
        when '3'
            'draft'
        end
end

transactions = smses.select { |a| a['address'] == '900' && a['body'].start_with?("VISA#{VISA_END} ") }

puts transactions.map { |a| a['body'] }