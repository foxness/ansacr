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

def parse_reported_datetime(date, time)
    DateTime.strptime "#{date} #{time or '00:00'}", '%d.%m.%y %H:%M'
end

def get_transactions(smses, visa_end)
    unprocessed_transactions = smses.select { |a| a['address'] == '900' && a['body'].start_with?("VISA#{visa_end} ") }
    body_regex = /^.{4}(?<visa>.{4}).(?<date>.{8})(?: (?<time>\d{2}:\d{2}) )?(?<type>.+) (?<amount>\d+(?:.\d+)?)(?<currency>[[:alpha:]]+)(?: (?<vendor>.+))? Баланс: (?<balance>\d+(?:.\d+)?)[[:alpha:]]+$/
    transactions = []
    unprocessed_transactions.each do |unprocessed_transaction|
        match = body_regex.match unprocessed_transaction['body']

        unless match
            raise 'FOUND A NON-MATCHING BODY' unless unprocessed_transaction['body'].include? 'ОТКАЗ'
            next
        end

        transaction = Hash.new

        transaction['date_received'] = unprocessed_transaction['date']
        transaction['date_sent'] = unprocessed_transaction['date_sent']
        transaction['body'] = unprocessed_transaction['body']

        transaction['visa'] = match.named_captures['visa']
        transaction['reported_date'] = parse_reported_datetime match.named_captures['date'], match.named_captures['time']
        transaction['type'] = match.named_captures['type']
        transaction['amount'] = match.named_captures['amount'].to_f
        transaction['currency'] = match.named_captures['currency']
        transaction['vendor'] = match.named_captures['vendor']
        transaction['balance'] = match.named_captures['balance'].to_f

        transactions << transaction
    end

    transactions
end

def serialize_transaction(transaction)
    # transaction['body']
    transaction.inspect
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