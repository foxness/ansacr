require 'date'

VISA_END = '1234'

def get_unprocessed_file
    unprocessed_dir = File.join(File.dirname(File.dirname(__FILE__)), 'data', 'unprocessed')
    Dir[File.join unprocessed_dir, '*'].first
end

def parse_smses(raw_file)
    sms_regex = /<sms protocol="(?<protocol>[^"]+)" address="(?<address>[^"]+)" date="(?<date>[^"]+)" type="(?<type>[^"]+)" subject="(?<subject>[^"]+)" body=(?<body>('[^']*')|("[^"]*")) toa="(?<toa>[^"]+)" sc_toa="(?<sc_toa>[^"]+)" service_center="(?<service_center>[^"]+)" read="(?<read>[^"]+)" status="(?<status>[^"]+)" locked="(?<locked>[^"]+)" date_sent="(?<date_sent>[^"]+)" readable_date="(?<readable_date>[^"]+)" contact_name="(?<contact_name>[^"]+)" \/>/
    
    sms_entry_count = raw_file.scan(/<sms /).length
    
    smses = raw_file.each_line.map { |a| sms_regex.match(a) }.compact.map { |a| a.named_captures }
    
    raise 'DISCREPANCY DETECTED' unless sms_entry_count == smses.length
    
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

    smses
end

def get_transactions(smses, visa_end)
    transactions = smses.select { |a| a['address'] == '900' && a['body'].start_with?("VISA#{visa_end} ") }
    transactions.each do |transaction|
        transaction['newbody'] = transaction['body'][18..-1]
        transaction['newbody'] = transaction['newbody'][6..-1] if transaction['newbody'][0, 5] =~ /\d{2}:\d{2}/
    end
    transactions
end

def serialize_transaction(transaction)
    transaction['newbody']
end

def serialize_transactions(transactions)
    transactions.inject('') { |result, rnsct| "#{result}#{serialize_transaction(rnsct)}\n" }.rstrip
end

def main
    filename = get_unprocessed_file
    raw = File.read filename
    smses = parse_smses raw
    transactions = get_transactions smses, VISA_END
    serialized = serialize_transactions transactions
    processed_filepath = File.join(File.dirname(File.dirname(filename)), 'processed', File.basename(filename, '.xml') + '.rnsct')
    File.write processed_filepath, serialized
end

main