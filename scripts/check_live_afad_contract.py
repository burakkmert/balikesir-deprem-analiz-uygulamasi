import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone

def perform_live_afad_contract_check():
    now_utc = datetime.now(timezone.utc)
    start_time = now_utc - timedelta(days=7)
    
    start_str = start_time.strftime("%Y-%m-%d %H:%M:%S")
    end_str = now_utc.strftime("%Y-%m-%d %H:%M:%S")
    
    # Bounding box for Balikesir center (39.6484, 27.8826) 50km
    params = {
        'start': start_str,
        'end': end_str,
        'minlat': '39.1984',
        'maxlat': '40.0984',
        'minlon': '27.2982',
        'maxlon': '28.4670',
        'minmag': '1.5',
        'orderby': 'timedesc',
        'limit': '5',
        'offset': '0'
    }
    
    base_url = "https://deprem.afad.gov.tr/apiv2/event/filter"
    query_str = urllib.parse.urlencode(params)
    full_url = f"{base_url}?{query_str}"
    
    result_data = {
        "checkTimestamp": now_utc.isoformat(),
        "requestUrl": full_url,
        "queryParamsSent": params,
        "httpStatusCode": None,
        "status": "FAILED",
        "rawSample": None,
        "learnedDetails": {
            "fieldsMapped": [],
            "dateFormatObserved": None,
            "hasExplicitTimezone": None,
            "sampleCountReceived": 0,
            "notes": ""
        }
    }
    
    req = urllib.request.Request(
        full_url,
        headers={'User-Agent': 'AfetAnalizBalikesir/1.0', 'Accept': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.status
            result_data["httpStatusCode"] = status_code
            body = response.read().decode('utf-8')
            
            if status_code == 200:
                result_data["status"] = "SUCCESS"
                data = json.loads(body)
                if isinstance(data, list):
                    result_data["learnedDetails"]["sampleCountReceived"] = len(data)
                    if len(data) > 0:
                        first_item = data[0]
                        result_data["rawSample"] = first_item
                        result_data["learnedDetails"]["fieldsMapped"] = list(first_item.keys())
                        date_str = str(first_item.get("date") or first_item.get("tarih") or "")
                        result_data["learnedDetails"]["dateFormatObserved"] = date_str
                        result_data["learnedDetails"]["hasExplicitTimezone"] = ("Z" in date_str or "+" in date_str or "-" in date_str[10:])
                        result_data["learnedDetails"]["notes"] = "Live official AFAD contract verified successfully with active schema fields."
                    else:
                        result_data["learnedDetails"]["notes"] = "HTTP 200 returned empty list for given 7-day query window."
                else:
                    result_data["learnedDetails"]["notes"] = f"Response body was not a JSON list: {type(data)}"
            else:
                result_data["learnedDetails"]["notes"] = f"AFAD returned non-200 HTTP status: {status_code}"
    except Exception as e:
        result_data["learnedDetails"]["notes"] = f"Live connection check failed or timed out: {str(e)}"
        print(f"Live AFAD contract check warning: {e}")
        
    out_path = "docs/afad_contract_check.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result_data, f, ensure_ascii=False, indent=2)
    
    print(f"Saved live AFAD contract check to {out_path} (Status: {result_data['status']})")

if __name__ == "__main__":
    perform_live_afad_contract_check()
