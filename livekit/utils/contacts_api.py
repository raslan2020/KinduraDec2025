"""
Contacts API module for LiveKit agent.
Reads user's contacts (family, caregivers, emergency contacts) from the database.
"""
import os
import httpx
from typing import Optional, List, Dict, Any
from utils.global_variables import BACKEND_URL


class ContactsAPI:
    """API client for reading user contacts"""

    def __init__(self, auth_token: str):
        self.auth_token = auth_token
        self.base_url = BACKEND_URL

    async def get_contacts(self, contact_type: Optional[str] = None) -> Optional[List[Dict[str, Any]]]:
        """
        Get all contacts for the user.

        Args:
            contact_type: Optional filter by type (family, caregiver, emergency, doctor, pharmacy, other)

        Returns:
            List of contacts or None if error
        """
        try:
            params = {}
            if contact_type:
                params['type'] = contact_type

            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.base_url}/contacts/",
                    headers={"Authorization": f"Token {self.auth_token}"},
                    params=params
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return data.get('result', [])
                    return []
                else:
                    print(f"❌ Failed to get contacts: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting contacts: {e}")
            return None

    async def get_emergency_contacts(self) -> Optional[List[Dict[str, Any]]]:
        """Get emergency contacts only"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.base_url}/contacts/emergency/",
                    headers={"Authorization": f"Token {self.auth_token}"}
                )

                if response.status_code == 200:
                    data = response.json()
                    if data.get('status'):
                        return data.get('result', [])
                    return []
                else:
                    print(f"❌ Failed to get emergency contacts: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error getting emergency contacts: {e}")
            return None

    async def get_caregivers(self) -> Optional[List[Dict[str, Any]]]:
        """Get caregiver contacts only"""
        return await self.get_contacts(contact_type='caregiver')

    async def get_family(self) -> Optional[List[Dict[str, Any]]]:
        """Get family contacts only"""
        return await self.get_contacts(contact_type='family')

    def format_contacts_for_context(self, contacts: List[Dict[str, Any]]) -> str:
        """Format contacts list for agent context"""
        if not contacts:
            return "No contacts saved."

        lines = ["Your saved contacts:"]

        for contact in contacts:
            name = contact.get('name', 'Unknown')
            contact_type = contact.get('contact_type_display', contact.get('contact_type', 'Other'))
            relationship = contact.get('relationship_display', contact.get('relationship', ''))
            phone = contact.get('phone_number', '')
            is_emergency = contact.get('is_emergency', False)

            emergency_tag = " [EMERGENCY]" if is_emergency else ""
            phone_info = f" - {phone}" if phone else ""

            lines.append(f"- {name} ({contact_type}, {relationship}){phone_info}{emergency_tag}")

        return "\n".join(lines)

    def format_emergency_contacts_summary(self, contacts: List[Dict[str, Any]]) -> str:
        """Format emergency contacts for quick reference"""
        if not contacts:
            return "No emergency contacts set up."

        lines = ["Emergency contacts:"]
        for contact in contacts:
            name = contact.get('name', 'Unknown')
            phone = contact.get('phone_number', 'No phone')
            relationship = contact.get('relationship_display', contact.get('relationship', ''))
            lines.append(f"- {name} ({relationship}): {phone}")

        return "\n".join(lines)
