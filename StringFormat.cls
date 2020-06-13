global with sharing class StringFormat implements vlocityins2.VlocityOpenInterface {

    // This is used for debugging purposes: a method can put information in this, and
    // if an exception is thrown, it will be included in the report back to the caller
    private String lastTidbit = '';

    /*
     *  Logging Management
     *
     *  The normal mechanism for debugging in Apex is to System.debug() something, but that ends
     *  up hard to retrieve from normal usage.  This is an alternative, that allows you to generate
     *  a log file that gets returned to an OmniScript that can be displayed in a selectable items
     *  element.  It's a bit tricky, in that we need to format the data properly, but not terribly
     *  tricky.
     */
    private List<Map<String,String>> debugLog;

    // Initialize the log, add it to the output.  Since the variable is put into the output by
    // reference, we can keep adding things to the list and the lastest version will be automatically
    // returned, no need to keep putting it into output after this initial call.
    private void initLog(Map<String,Object> output) {
        debugLog = new List<Map<String,String>>();
        output.put('debugLog', debugLog);
    }

    private void addLog(String message) {
        Map<String,String> thisMessage = new Map<String,String>();

        thisMessage.put('Timestamp', String.valueOf(Datetime.now()));
        thisMessage.put('Text', message);

        debugLog.add(thisMessage);
    }

    /*
     * Standard entrypoint for VlocityOpenInterface.
     */
     global Boolean InvokeMethod( String methodName, Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
        try {
            initLog(output);

            if (methodName.equals('format')) {
                doFormat(methodName, input, output, options);
                return true;
            }

        } catch (Exception e) {
            output.put('Error', e.getMessage());
            output.put('ErrorLine', e.getLineNumber());
            output.put('TidBit', lastTidbit);
            output.put('Method', methodName);
        }

        return false;
    }


    // https://salesforce.stackexchange.com/questions/4448/default-currency-symbol
    public static String getCurSymbol() {
        String Iso = UserInfo.getDefaultCurrency();
        String currencySymbol = 
          ('USD' == Iso ? '$' : 
          ('CAD' == Iso ? '$' : 
          ('EUR' == Iso ? '€' : 
          ('GBP' == Iso ? '£' : 
          ('JPY' == Iso ? '¥' : 
          ('KRW' == Iso ? '₩' : 
          ('CNY' == Iso ? '元' : 
          Iso)))))));
          return currencySymbol;
   }

    private String decimalFormat(String data, String args) {
        Decimal d = Decimal.valueOf(data);
        Integer digits = Integer.valueOf(args);
        String amount;

        // Easiest way to get locale information
        // https://salesforce.stackexchange.com/questions/21395/which-decimal-symbol-is-used-in-the-current-users-locale
        Decimal value = 1000.10;
        String formattedValue = value.format();
        String thousandSep = formattedValue.substring(1,2);
        String decimalSep = formattedValue.substring(5,6);


        amount = d.format();

        Integer decPos = amount.indexOf(decimalSep);

        if (decPos == -1) {
            amount += decimalSep;
        }

        // Pad out to correct length
        while (amount.indexOf(decimalSep) > (amount.length() - digits)) {
            amount += '0';

        }
        return amount;
    }
    /**
     * doFormat
     * 
     * The format is passed an input called 'format' and then any number of other, named arguments
     * 
     * The format is literal text with {}s inserted that define a format specification
     * The format specification consists of name:formatting
     * The name is the name of the data to fist out of input (and should be a string)
     * formatting consists of a letter, indicating a type, and then any arguments to that format
     * Formatting letters are:
     *      d       Decimal
     * 
     * Decimal's argument is the number of digits past the decimal point
     */
    private void doFormat(String methodName, Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
        String formatSpec = (String) input.get('format');
        String formatted = '';

        Integer cursor = 0;


        while (cursor < formatSpec.length()) {

            // Check for a \ to escape the next character
            if (formatSpec.substring(cursor, cursor+1) == '\\') {
                cursor += 1;
                formatted = formatted + formatSpec.substring(cursor, cursor+1);
                cursor += 1;
                continue;
            }

            // Check for a $ to insert the user's local currency (can use \$ to force a literal $)
            if (formatSpec.substring(cursor, cursor+1) == '$') {
                // Currency cur = Currency.getInstance(UserInfo.getDefaultCurrency());
                formatted = formatted + getCurSymbol();
                cursor += 1;
                continue;
            }

            // Looking for a { to indicate the start of a format specification
            if (formatSpec.substring(cursor, cursor+1) != '{') {
                formatted = formatted + formatSpec.substring(cursor, cursor+1);
                cursor += 1;
                continue;
            }

            cursor += 1;

            String name = '';
            // Now, look for everything up to a : for a name

            while (formatSpec.substring(cursor, cursor+1) != ':') {
                name = name +  formatSpec.substring(cursor, cursor+1);
                cursor += 1;
            }

            // Eat the :
            cursor += 1;

            String formatData = String.valueOf(input.get(name));

            String formatType  = formatSpec.substring(cursor, cursor+1);
            cursor += 1;

            String formatArgs = '';
            // Look for everything up to the close }
            while (formatSpec.substring(cursor, cursor+1) != '}') {
                formatArgs = formatArgs + formatSpec.substring(cursor, cursor+1);
                cursor += 1;
            }

            // Eat the }
            cursor += 1;

            if (formatType == 'd') {
                formatted = formatted + decimalFormat(formatData, formatArgs);
            } else if (formatType == 's') {
                formatted = formatted + formatData;
            } else if (formatType == 'u') {
                formatted = formatted + formatData.toUpperCase();
            }  else if (formatType == 'l') {
                formatted = formatted + formatData.toLowerCase();
            } else {
                formatted = formatted + ' { Invalid format type: ' + formatType + ' } ';
            }





        }

        output.put('results', formatted);
    }


}