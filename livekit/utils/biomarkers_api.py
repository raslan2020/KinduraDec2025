"""
Biomarkers API module for LiveKit agent.
Reads user's lab results, biomarkers, and health insights from the database.
"""
import os
import httpx
from typing import Optional, List, Dict, Any, Union
from datetime import datetime

# Get base URL from environment or use default
BACKEND_URL = os.getenv("API_BASE_URL", "http://localhost:8000/api")


class BiomarkersAPI:
    """API client for reading user biomarkers and lab results"""

    def __init__(self, auth_token: str, base_url: str = None):
        self.auth_token = auth_token
        self.base_url = base_url or BACKEND_URL
        print(f"🔬 BiomarkersAPI initialized with base_url: {self.base_url}")

    async def get_all_biomarkers(self, category: Optional[str] = None) -> Optional[Any]:
        """
        Get all biomarkers for the user with their latest values and trends.

        Args:
            category: Optional category filter (heart_health, liver, kidney, etc.)

        Returns:
            List of biomarkers or None
        """
        try:
            params = {}
            if category:
                params['category'] = category

            url = f"{self.base_url}/biomarkers/user/"
            print(f"🔬 BiomarkersAPI: GET {url}")
            print(f"🔬 BiomarkersAPI: Token: {self.auth_token[:20]}..." if self.auth_token and len(self.auth_token) > 20 else f"🔬 Token: {self.auth_token}")

            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    url,
                    headers={"Authorization": f"Token {self.auth_token}"},
                    params=params
                )

                print(f"🔬 BiomarkersAPI: Response status: {response.status_code}")

                if response.status_code == 200:
                    data = response.json()
                    print(f"🔬 BiomarkersAPI: Response keys: {list(data.keys()) if isinstance(data, dict) else 'not a dict'}")

                    if data.get('status'):
                        # API returns {status: true, result: [...], count: N}
                        result = data.get('result', [])
                        print(f"🔬 BiomarkersAPI: Found {len(result) if isinstance(result, list) else 'N/A'} biomarkers")
                        return result
                    else:
                        print(f"❌ BiomarkersAPI: status=false in response")
                    return None
                else:
                    print(f"❌ Failed to get biomarkers: {response.status_code}")
                    print(f"❌ Response body: {response.text[:500]}")
                    return None
        except Exception as e:
            print(f"❌ Error getting biomarkers: {e}")
            import traceback
            traceback.print_exc()
            return None

    async def get_labs_summary(self) -> Optional[Dict[str, Any]]:
        """
        Get a summary of the user's lab results.

        Returns:
            Dict with summary (total biomarkers, abnormal count, critical count, etc.)
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.base_url}/biomarkers/summary/",
                    headers={"Authorization": f"Token {self.auth_token}"}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return data.get('result', {})
                    return None
                else:
                    print(f"❌ Failed to get labs summary: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting labs summary: {e}")
            return None

    async def get_biomarker_detail(self, biomarker_id: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed information about a specific biomarker.

        Args:
            biomarker_id: The biomarker identifier (e.g., "glucose", "ldl_cholesterol")

        Returns:
            Dict with biomarker details, history, and trend
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.base_url}/biomarkers/{biomarker_id}/",
                    headers={"Authorization": f"Token {self.auth_token}"}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return data.get('result', {})
                    return None
                else:
                    print(f"❌ Failed to get biomarker detail: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting biomarker detail: {e}")
            return None

    async def get_health_insights(self) -> Optional[List[Dict[str, Any]]]:
        """
        Get health insights based on user's biomarker data.

        Returns:
            List of health insights with recommendations
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    f"{self.base_url}/biomarkers/insights/",
                    headers={"Authorization": f"Token {self.auth_token}"}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return {
                            'insights': data.get('result', []),
                            'summary': data.get('summary', {})
                        }
                    return None
                else:
                    print(f"❌ Failed to get health insights: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting health insights: {e}")
            return None

    async def get_biomarker_categories(self) -> Optional[Dict[str, int]]:
        """
        Get biomarker categories and counts.

        Returns:
            Dict mapping category names to counts
        """
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.base_url}/biomarkers/categories/",
                    headers={"Authorization": f"Token {self.auth_token}"}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return data.get('result', {})
                    return None
                else:
                    print(f"❌ Failed to get categories: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting categories: {e}")
            return None

    def format_biomarkers_for_agent(self, biomarkers: List[Dict]) -> str:
        """
        Format biomarkers data into a readable summary for the agent.

        Args:
            biomarkers: List of biomarker data from API

        Returns:
            Formatted string summary
        """
        if not biomarkers:
            return "No lab results available."

        lines = ["Your Lab Results Summary:\n"]

        # Group by status
        abnormal = []
        normal = []

        for bio in biomarkers:
            # Handle the actual API response structure
            # API returns: definition.name, latestObservation.valueNum, etc.
            definition = bio.get('definition', {})
            latest_obs = bio.get('latestObservation', {})

            # Get name from definition or fall back to old format
            name = definition.get('name') or bio.get('name', 'Unknown')

            # Get value from latestObservation or fall back to old format
            value = latest_obs.get('valueNum') or bio.get('latestValue') or bio.get('value')

            # Get unit from latestObservation or definition
            unit = latest_obs.get('unitOriginal') or definition.get('unit') or bio.get('unit', '')

            # Get status from latestObservation or determine from reference range
            status = latest_obs.get('status', 'unknown')

            # Get reference ranges from definition
            ref_ranges = definition.get('reference_ranges', [])
            ref_min = None
            ref_max = None
            if ref_ranges:
                # Use the first reference range (adult default)
                ref_min = ref_ranges[0].get('low')
                ref_max = ref_ranges[0].get('high')

            # Fall back to old format for reference range
            if ref_min is None and ref_max is None:
                ref_range = bio.get('referenceRange', {})
                ref_min = ref_range.get('min')
                ref_max = ref_range.get('max')

            if value is not None:
                # Format the value
                if isinstance(value, float):
                    value = round(value, 1)

                entry = f"- {name}: {value} {unit}"

                # Add reference range if available
                if ref_min is not None or ref_max is not None:
                    if ref_min is not None and ref_max is not None:
                        entry += f" (normal: {ref_min}-{ref_max})"
                    elif ref_max is not None:
                        entry += f" (normal: below {ref_max})"
                    elif ref_min is not None:
                        entry += f" (normal: above {ref_min})"

                # Determine status from value vs reference range if status is unknown
                if status == 'unknown' and value is not None:
                    if ref_max is not None and value > ref_max:
                        status = 'high'
                    elif ref_min is not None and value < ref_min:
                        status = 'low'
                    else:
                        status = 'normal'

                # Add status indicator
                if status in ['high', 'critical_high', 'H', 'HH']:
                    entry += " ⚠️ HIGH"
                    abnormal.append(entry)
                elif status in ['low', 'critical_low', 'L', 'LL']:
                    entry += " ⚠️ LOW"
                    abnormal.append(entry)
                else:
                    normal.append(entry)

        # Abnormal results first
        if abnormal:
            lines.append("⚠️ Results Requiring Attention:")
            lines.extend(abnormal)
            lines.append("")

        # Then normal results (summarized)
        if normal:
            lines.append(f"✅ {len(normal)} biomarkers within normal range")
            # List them briefly
            for entry in normal[:10]:  # Show first 10
                lines.append(entry)
            if len(normal) > 10:
                lines.append(f"... and {len(normal) - 10} more")

        return "\n".join(lines)

    def format_insights_for_agent(self, insights_data: Dict) -> str:
        """
        Format health insights into a readable summary for the agent.

        Args:
            insights_data: Dict with insights and summary

        Returns:
            Formatted string summary
        """
        if not insights_data:
            return "No health insights available."

        insights = insights_data.get('insights', [])
        summary = insights_data.get('summary', {})

        if not insights:
            return "Your lab results look good. No specific health concerns identified."

        lines = ["Health Insights Based on Your Lab Results:\n"]

        # Add summary
        critical = summary.get('criticalCount', 0)
        warnings = summary.get('warningCount', 0)

        if critical > 0:
            lines.append(f"🚨 {critical} critical issue(s) requiring attention")
        if warnings > 0:
            lines.append(f"⚠️ {warnings} warning(s) to discuss with your doctor")
        lines.append("")

        # Add individual insights
        for insight in insights[:5]:  # Limit to top 5
            title = insight.get('title', 'Insight')
            severity = insight.get('severity', 'info')
            description = insight.get('description', '')

            icon = "🚨" if severity == 'critical' else "⚠️" if severity == 'warning' else "ℹ️"
            lines.append(f"{icon} {title}")

            if description:
                lines.append(f"   {description[:200]}")

            # Add key recommendations
            actions = insight.get('actions', [])
            if actions:
                lines.append("   Recommendations:")
                for action in actions[:3]:
                    lines.append(f"   • {action}")

            lines.append("")

        return "\n".join(lines)

    def format_biomarker_detail_for_agent(self, detail: Dict) -> str:
        """
        Format a specific biomarker's details for the agent.

        Args:
            detail: Biomarker detail data from API

        Returns:
            Formatted string
        """
        if not detail:
            return "Biomarker details not found."

        # Handle the actual API response structure
        definition = detail.get('definition', {})
        latest_obs = detail.get('latestObservation', {})

        name = definition.get('name') or detail.get('name', 'Unknown')
        value = latest_obs.get('valueNum') or detail.get('latestValue') or detail.get('value')
        unit = latest_obs.get('unitOriginal') or definition.get('unit') or detail.get('unit', '')
        status = latest_obs.get('status', 'unknown')
        trend = detail.get('trendDirection', 'stable')

        lines = [f"Details for {name}:\n"]

        # Get reference ranges from definition
        ref_ranges = definition.get('reference_ranges', [])
        ref_min = None
        ref_max = None
        if ref_ranges:
            ref_min = ref_ranges[0].get('low')
            ref_max = ref_ranges[0].get('high')

        # Fall back to old format
        if ref_min is None and ref_max is None:
            ref_range = detail.get('referenceRange', {})
            ref_min = ref_range.get('min')
            ref_max = ref_range.get('max')

        # Current value
        if value is not None:
            if isinstance(value, float):
                value = round(value, 1)
            lines.append(f"Current Value: {value} {unit}")

            # Determine status from value vs reference range if status is unknown
            if status == 'unknown' and value is not None:
                if ref_max is not None and value > ref_max:
                    status = 'high'
                elif ref_min is not None and value < ref_min:
                    status = 'low'
                else:
                    status = 'normal'

            # Status
            if status in ['high', 'critical_high', 'H', 'HH']:
                lines.append(f"Status: ⚠️ Above normal range")
            elif status in ['low', 'critical_low', 'L', 'LL']:
                lines.append(f"Status: ⚠️ Below normal range")
            else:
                lines.append(f"Status: ✅ Within normal range")

        # Trend
        if trend == 'improving':
            lines.append(f"Trend: 📈 Improving")
        elif trend == 'worsening':
            lines.append(f"Trend: 📉 Worsening")
        else:
            lines.append(f"Trend: ➡️ Stable")

        # Reference range
        if ref_min is not None or ref_max is not None:
            if ref_min is not None and ref_max is not None:
                lines.append(f"Normal Range: {ref_min}-{ref_max} {unit}")
            elif ref_max is not None:
                lines.append(f"Normal Range: Below {ref_max} {unit}")
            elif ref_min is not None:
                lines.append(f"Normal Range: Above {ref_min} {unit}")

        # Description from definition
        description = definition.get('description')
        if description:
            lines.append(f"\nWhat it measures: {description}")

        # Clinical significance
        clinical_sig = definition.get('clinical_significance')
        if clinical_sig:
            lines.append(f"Clinical Significance: {clinical_sig}")

        return "\n".join(lines)
